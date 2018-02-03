import { HandlerContext } from "@atomist/automation-client";
import { runCommand } from "@atomist/automation-client/action/cli/commandLine";
import {
    automationClient,
    runningAutomationClient,
} from "@atomist/automation-client/automationClient";
import { findConfiguration } from "@atomist/automation-client/configuration";
import { logger } from "@atomist/automation-client/internal/util/logger";
import { GitHubRepoRef } from "@atomist/automation-client/operations/common/GitHubRepoRef";
import { GitCommandGitProject } from "@atomist/automation-client/project/git/GitCommandGitProject";
import { enableDefaultScanning } from "@atomist/automation-client/scan";

export const Owner: string = process.env.OWNER || "atomisthqa";
export const Repository: string = process.env.REPOSITORY || "lifecycle-automation";
export const Branch: string = process.env.BRANCH || "master";
export const UpdatePolicy: string =  process.env.UPDATE_POLICY || "PUSH";

logger.info("Starting automation client sidecar");

GitCommandGitProject.cloned({ token: process.env.GITHUB_TOKEN },
    new GitHubRepoRef(Owner, Repository, Branch))
    .then(project => {
        return { project, pj: require(`${project.baseDir}/package.json`) };
    })
    .then(details => {
        return runCommand("git rev-parse HEAD", { cwd: details.project.baseDir })
            .then(result => {
                return {...details, sha: result.stdout.replace("\n", "") };
            });
    })
    .then(details => {
        const configuration = enableDefaultScanning(findConfiguration());
        configuration.name = `${details.pj.name}-sidecar`;

        const node = automationClient(configuration);
        return node.run()
            .then(() => logger.info("Successfully completed startup of process '%s'", process.pid))
            .then(() => {

            if (UpdatePolicy.toLowerCase() === "push") {
                runningAutomationClient.automationServer.onEvent({
                        data: {
                            Push: [{
                                branch: Branch,
                                repo: {
                                    owner: Owner,
                                    name: Repository,
                                },
                                after: {
                                    sha: details.sha,
                                },
                            }],
                        },
                        extensions: {
                            operationName: "UpdateOnPush",
                        },
                    }
                    , { teamId: process.env.TEAM_ID } as any as HandlerContext);
                }
            });
    })
    .catch(err => logger.error(err));
