import {
    EventFired,
    EventHandler,
    HandleEvent,
    HandlerContext,
    HandlerResult,
} from "@atomist/automation-client";
import * as GraphQL from "@atomist/automation-client/graph/graphQL";
import {
    Branch,
    Owner,
    Repository,
} from "../../start.client";
import * as graphql from "../../typings/types";
import { restartClient } from "../restart.client";

@EventHandler("Start or update automation client after release",
    GraphQL.subscriptionFromFile(
        "../../graphql/subscription/updateOnRelease",
        __dirname,
        {
            owner: Owner,
            repository: Repository,
            branch: Branch,
        }))
export class UpdateOnRelease implements HandleEvent<graphql.UpdateOnRelease.Subscription> {

    public handle(e: EventFired<graphql.UpdateOnRelease.Subscription>, ctx: HandlerContext): Promise<HandlerResult> {
        const commit = e.data.Release[0].tag.commit;
        return restartClient({
            owner: commit.repo.owner,
            repository: commit.repo.name,
            branch: commit.pushes[0].branch,
            sha: commit.sha,
            teamId: ctx.teamId,
        });
    }
}
