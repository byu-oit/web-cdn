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

const log = require('winston');
const fs = require('fs-extra');
const decompress = require('decompress');
const path = require('path');
const os = require('os');
const {hash} = require('./util');

const tmpdir = path.join(os.tmpdir(), 'tarball-downloads');

module.exports = async function getTarball(httpClient, url, dest) {
    let tarName = hash('sha256', url).hex;

    log.debug(`downloading tarball from ${url} to ${dest}`);

    await fs.emptyDir(dest);
    await fs.ensureDir(tmpdir);

    let tar = path.join(tmpdir, tarName + '.tgz');
    log.debug('Downloading to temp file', tar);

    await httpClient.stream(url, tar);

    await decompress(tar, dest, {
        map: file => {
            let p = file.path;
            file.path = p.substr(p.indexOf(path.sep));
            return file;
        }
    });
    log.debug('Finished decompressing to', dest);
};
