import axios from "axios";
import { configuration } from "../atomist.config";
import { api } from "../util/github";
import { ClientDetails } from "./restart.client";

export function createGitHubStatus(details: ClientDetails,
                                   state: "pending" | "success" | "failure",
                                   targetUrl?: string): Promise<any> {
    if (details.sha) {
        const github = api(configuration.token);
        return github.repos.createStatus({
            owner: details.owner,
            repo: details.repository,
            sha: details.sha,
            state,
            description: `Atomist CI build ${state}`,
            context: `continuous-integration/atomist/push`,
            target_url: targetUrl,
        });
    } else {
        return Promise.resolve();
    }
}

export function uploadGist(details: ClientDetails,
                           log: string): Promise<string> {
    const github = api(configuration.token);
    const stripAnsi = require("strip-ansi");
    const payload = {
        public: false,
        description: `Build log for ${details.owner}/${details.repository}`,
        files: "",
    };
    (payload as any).files = {};
    payload.files[`${details.owner}_${details.repository}.log`] = {
        content: stripAnsi(log),
    };
    return github.gists.create(payload)
        .then(result => {
            return result.data.html_url;
        });
}

export function sendBuildEvent(status: "STARTED" | "SUCCESS" | "FAILURE",
                               phase: "STARTED" | "FINALIZED" = "FINALIZED",
                               details: ClientDetails,
                               url?: string): Promise<any> {
    if (details.sha) {
        if (!url) {
            url = `https://github.com/${details.owner}/${details.repository}/commit/${details.sha}`;
        }
        const config = {
            headers: {
                "Content-Type": "application/json",
            },
        };

        const payload = {
            name: `Build ${details.branch}`,
            duration: 3,
            build: {
                number: "Build",
                scm: {
                    commit: details.sha,
                    url: `https://github.com/${details.owner}/${details.repository}`,
                    branch: details.branch,
                },
                phase,
                status,
                full_url: url,
            },
        };

        // TODO cd externalize the url
        return axios.post(
            `https://webhook-staging.atomist.services/atomist/jenkins/teams/${details.teamId}`,
            payload,
            config);
    } else {
        return Promise.resolve();
    }
}
