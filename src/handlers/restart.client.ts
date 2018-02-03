import {
    failure,
    HandlerResult,
    logger,
    success,
    SuccessPromise,
} from "@atomist/automation-client";
import { runCommand } from "@atomist/automation-client/action/cli/commandLine";
import { GitHubRepoRef } from "@atomist/automation-client/operations/common/GitHubRepoRef";
import { GitCommandGitProject } from "@atomist/automation-client/project/git/GitCommandGitProject";
import { ChildProcess, spawn } from "child_process";
import * as kill from "tree-kill";
import { configuration } from "../atomist.config";
import {
    Branch,
    Owner,
    Repository,
} from "../start.client";
import {
    createGitHubStatus,
    sendBuildEvent,
    uploadGist,
} from "./helpers";

export interface ClientDetails {
    owner: string;
    repository: string;
    branch: string;
    sha: string;
    teamId: string;
}

let runningProcess: ChildProcess = null;

export function restartClient(details: ClientDetails): Promise<HandlerResult> {
    if (details.owner === Owner && details.repository === Repository && details.branch === Branch) {
        return createGitHubStatus(details, "pending")
            .then(() => sendBuildEvent("STARTED", "STARTED", details))
            .then(() => {
                return GitCommandGitProject.cloned({ token: configuration.token },
                    new GitHubRepoRef(details.owner, details.repository, details.sha));
            })
            .then(project => {
                return project.configureFromRemote()
                    .then(() => {
                        return project;
                    });
            })
            .then(project => {
                const baseDir = project.baseDir;
                return runCommand(
                    `npm install && npm run compile && npm run test`,
                    {
                        cwd: baseDir,
                        env: {
                            ...process.env,
                        },
                    })
                    .then(result => {
                        return uploadGist(details, `stdout: ${result.stdout}\n\nstderr: ${result.stderr}`)
                            .then(url => Promise.all([
                                createGitHubStatus(details, "success", url),
                                sendBuildEvent("SUCCESS", "FINALIZED", details, url),
                            ]));
                    })
                    .catch(result => {
                        return uploadGist(details, `stdout: ${result.stdout}\n\nstderr: ${result.stderr}`)
                            .then(url => Promise.all([
                                createGitHubStatus(details, "failure", url),
                                sendBuildEvent("FAILURE", "FINALIZED", details, url),
                            ]));
                    })
                    .then(() => {
                        const dateFormat = require("dateformat");
                        const pj = require(`${baseDir}/package.json`);
                        const version = pj.version;
                        return runCommand(
                            `npm version ${version}-sidecar.${dateFormat(Date.now(), "yyyymmddHHMMss")}`,
                            {
                                cwd: baseDir,
                                env: {
                                    ...process.env,
                                },
                            });
                    })
                    .then(() => {
                        let running = true;
                        const child = spawn(
                            "node_modules/.bin/atomist",
                            ["start", "--no-compile", "--no-install"],
                            {
                                cwd: baseDir,
                                env: {
                                    ...process.env,
                                },
                                stdio: "inherit",
                            });

                        child.on("exit", () => {
                            running = false;
                        });

                        setTimeout(() => {
                            if (running) {
                                if (runningProcess) {
                                    logger.info("Shutting down previous process...");
                                    kill(runningProcess.pid);
                                }
                                runningProcess = child;
                            }
                        }, 20000);
                    });
            })
            .then(success)
            .catch(err => {
                logger.error(err);
                return failure(err);
            });
    } else {
        return SuccessPromise;
    }
}
