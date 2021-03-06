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

module.exports = {

    mapLibraries(manifest, callback) {
        return Object.entries(manifest.libraries).map(([id, lib]) => {
           return callback(id, lib);
        });
    },

    async promiseLibraries(manifest, fun) {
        let result = {};
        return Promise.all(
            this.mapLibraries(manifest, (id, lib) => {
                return Promise.resolve(fun(id, lib))
                    .then(r => result[id] = r);
            })
        ).then(() => result);
    }

};
