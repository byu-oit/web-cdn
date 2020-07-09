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

const AWS = require('aws-sdk');
const CodeBuild = new AWS.CodeBuild();
const HttpError = require('./http-error');

module.exports = function startAssembler(name, branch) {
    console.log(`Starting Assembler Codebuild Project ${name}@${branch}`);
    return CodeBuild.startBuild({
        projectName: name,
        sourceVersion: branch
    }).promise()
        .catch(err => {
            console.error('got codebuild error', err);
            throw new HttpError(500, 'Unable to start codebuild: ' + err.message);
        })
        .then(data => data.build.id);
};
