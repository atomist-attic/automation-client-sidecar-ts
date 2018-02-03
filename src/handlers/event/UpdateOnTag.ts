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

@EventHandler("Start or update automation client after tag",
    GraphQL.subscriptionFromFile(
        "../../graphql/subscription/updateOnTag",
        __dirname,
        {
            owner: Owner,
            repository: Repository,
            branch: Branch,
        }))
export class UpdateOnTag implements HandleEvent<graphql.UpdateOnTag.Subscription> {

    public handle(e: EventFired<graphql.UpdateOnTag.Subscription>, ctx: HandlerContext): Promise<HandlerResult> {
        const commit = e.data.Tag[0].commit;
        return restartClient({
            owner: commit.repo.owner,
            repository: commit.repo.name,
            branch: commit.pushes[0].branch,
            sha: commit.sha,
            teamId: ctx.teamId,
        });
    }
}
