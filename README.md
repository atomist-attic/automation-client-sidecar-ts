# @atomist/automation-client-sidecar-ts

This project allows to run automation client via the deployment of a sidecar that handles build, test and deploy of the
monitored automation client project.

## Starting the Sidecar

```
$ docker run -it --rm -e GITHUB_TOKEN=<your github token> \
    -e TEAM_ID=<your atomist team id> \
    -e OWNER=atomisthqa \
    -e REPOSITORY=lifecycle-automation \
    -e UPDATE_POLICY=push \
    -e BRANCH=master \
    automation-client-sidecar
```

This will create a new automation client for every push to the repository `atomist/lifecycle-automation`. Once the new version has been started successfully, the previous version is gracefully stopped.

Possible `UPDATE_POLICY` values are: `push`, `tag` and `release` giving you flexibility to decide when to update your
automation client. `tag` and/or `release` are more suited for production/stable environments; `push` is good for 
connecting to a staging or testing environment.

The `GITHUB_TOKEN` _must_ have the following scopes: 
 * `read:org` to validate your credentials to start a client for the given Atomist team
 * `repo` to create GitHub statuses and tags on the monitored repository
 * `gist` to upload GitHub gists for build and test logs
 * `read:user` to read your user details to create a Git tag
 * `user:email` to read your email to create a Git tag

## Support

General support questions should be discussed in the `#support`
channel on our community Slack team
at [atomist-community.slack.com][slack].

If you find a problem, please create an [issue][].

[issue]: https://github.com/atomist/lifecycle-automation/issues

## Contributing

If you are interested in contributing to the Atomist open source
projects, please see our [contributing guidelines][contrib] and
our [code of conduct][code].

[contrib]: https://github.com/atomist/welcome/blob/master/CONTRIBUTING.md
[code]: https://github.com/atomist/welcome/blob/master/CODE_OF_CONDUCT.md

## Development

You will need to have [Node.js][node] installed.  To verify that the
right versions are installed, please run:

```
$ node -v
v8.4.0
$ npm -v
5.4.1
```

[node]: https://nodejs.org/ (Node.js)

### Build and Test

Command | Reason
------- | ------
`npm install` | to install all the required packages
`npm run build` | lint, compile, and test
`npm start` | to start the Atomist automation client
`npm run autostart` | run the client, refreshing when files change
`npm run lint` | to run tslint against the TypeScript
`npm run compile` | to compile all TypeScript into JavaScript
`npm test` | to run tests and ensure everything is working
`npm run autotest` | run tests continuously
`npm run clean` | remove stray compiled JavaScript files and build directory

### Release

To create a new release of the project, simply push a tag of the form
`M.N.P` where `M`, `N`, and `P` are integers that form the next
appropriate [semantic version][semver] for release.  The version in
the package.json is replaced by the build and is totally ignored!  For
example:

[semver]: http://semver.org

```
$ git tag -a 1.2.3
$ git push --tags
```

The Travis CI build (see badge at the top of this page) will publish
the NPM module and automatically create a GitHub release using the tag
name for the release and the comment provided on the annotated tag as
the contents of the release notes.

---

Created by [Atomist][atomist].
Need Help?  [Join our Slack team][slack].

[atomist]: https://www.atomist.com/
[slack]: https://join.atomist.com
