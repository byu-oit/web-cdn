/*
 *  @license
 *    Copyright 2020 Brigham Young University
 *
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */
"use strict";

const util = require('../util/util');
const constants = require('../constants');
const log = require('winston');
const yaml = require('node-yaml');
const moment = require('moment-timezone');
const runCommand = require('../util/run-command');
const path = require('path');

const graphql = require('graphql.js');

const httpFactory = require('../util/http');

function clientHeaders() {
    if (!ghUser || !ghToken) {
        throw new Error('Must have specified a github user and token!');
    }
    return {
        'Authorization': computeAuthHeader(ghUser, ghToken)
    };
}

const http = httpFactory({
    concurrency: 2, // Github has pretty strict abuse limits. Let's not trigger them with too much concurrency.
    headers: clientHeaders,
});

const fs = require('fs-extra');

let ghUser, ghToken;

module.exports = class GithubProvider {

    static get id() {
        return constants.SOURCE_KEYS.GITHUB;
    }

    static validateConfig(options) {
        return true;
    }

    static setCredentials(user, token) {
        ghUser = user;
        ghToken = token;
    }

    constructor(source, opts) {
        let [owner, repo] = source.split('/');
        this.source = source;
        this.owner = owner;
        this.repo = repo;
        this.opts = opts;
        this.baseUri = `https://api.github.com/repos/${owner}/${repo}`;
    }

    async listRefs() {
        log.debug(`Listing refs for ${this.source}`);
        let client = graphql('https://api.github.com/graphql', {
            asJSON: true,
            headers: await http.headers(),
            fragments: {
                refFields: `on Ref {
	                            name
                                commit: target {
                                  sha: oid
                                  ... on Commit {
                                    date: committedDate
                                  }
                                }
                            }`
            }
        });

        let result = await client.query(`
            query {
              repository(owner: \"${this.owner}\", name: \"${this.repo}\" ) {
                branches: refs(refPrefix: \"refs/heads/\", first: 100) {
                  nodes {
                    ...refFields
                  }
                }
                tags: refs(refPrefix: \"refs/tags/\", first: 100) {
                  nodes {
                    ...refFields
                  }
                }
              }
            }`, {});

        log.debug(`Refs response for ${this.source}:`, JSON.stringify(result));

        let me = this;

        return Promise.all([].concat(
            result.repository.branches.nodes.map(it => toRefInfo(it, constants.REF_TYPES.BRANCH)),
            result.repository.tags.nodes.map(it => toRefInfo(it, constants.REF_TYPES.RELEASE)),
        ));


        async function toRefInfo(refObj, type) {
            let ref = refObj.name;
            let name = util.cleanRefName(ref);
            let config = await me.fetchRepoConfig(ref);
            return {
                ref,
                type,
                name,
                source_sha: refObj.commit.sha,
                last_updated: moment(refObj.commit.date).tz('America/Denver'),
                tarball_url: `${me.baseUri}/tarball/${ref}`,
                link: `https://github.com/${me.owner}/${me.repo}/tree/${ref}`,
                config
            }
        }
    }

    /**
     *
     * @param {githubInfo} ghInfo
     * @param {string} ref
     * @returns {Promise.<RepoConfig>}
     */
    async fetchRepoConfig(ref) {
        log.debug(`getting repo config for ${this.source}@${ref}`);

        try {
            let cfg = await http.getJson(`${this.baseUri}/contents/.cdn-config.yml?ref=${encodeURIComponent(ref)}`);
            return yaml.parse(Buffer.from(cfg.content, cfg.encoding));
        } catch (err) {
            const message = `Error getting repo config for github:${this.source}@${ref}: ${err.message}`;
            log.error(message, err);
            throw new Error(message);
        }
    }

    async fetchLinks(config) {
        const readme = await http.getJson(`${this.baseUri}/readme`);
        const readmeDownloadUrl = readme.download_url;

        return {
            source: `https://github.com/${this.owner}/${this.repo}`,
            issues: `https://github.com/${this.owner}/${this.repo}/issues`,
            docs: config.docs,
            readme: readmeDownloadUrl,
        };
    }

    async fetchReadme(ref) {
        log.debug(`Getting README for ${this.source}@${ref}`);

        try {
            const readme = await http.getJson(`${this.baseUri}/readme?ref=${encodeURIComponent(ref)}`);

            const content = Buffer.from(readme.content, readme.encoding).toString('utf8');

            return {
                filename: readme.name,
                content: content
            };
        } catch (err) {
            log.debug(`Error getting README for ${this.source}@${ref}`, err);
            return null;
        }
    }

    async fetchMainConfig() {
        return this.fetchRepoConfig('master');
    }

    async downloadRef(ref, destination) {
        const exists = await fs.pathExists(path.join(destination, '.git'));
        if (exists) {
            await fs.ensureDir(destination);
        } else {
            await fs.emptyDir(destination);
        }

        log.info(`Downloading ${this.source}@${ref} to ${destination} using git`);

        try {
            if (exists) {
                // await runCommand('git fetch ' + this.source, 'git', ['fetch', 'origin', ref]);
                // await runCommand('git rebase ' + this.source, 'git', ['pull']);
            } else {
                await runCommand('git clone ' + this.source, 'git', ['clone', '--branch', ref, '--depth', '1', `https://${ghUser}:${ghToken}@github.com/${this.owner}/${this.repo}.git`, destination]);
            }
        } catch (err) {
            log.error(`Error getting ${this.source}@${ref} via git`, err);
            throw err;
        }
        log.info(`Finished downloading ${this.source}@${ref}`)
    }

};

function computeAuthHeader(user, token) {
    return 'Basic ' + new Buffer(user + ':' + token).toString('base64');
}
