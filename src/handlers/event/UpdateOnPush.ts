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

@EventHandler("Start or update automation client after push",
    GraphQL.subscriptionFromFile(
        "../../graphql/subscription/updateOnPush",
        __dirname,
        {
            owner: Owner,
            repository: Repository,
            branch: Branch,
        }))
export class UpdateOnPush implements HandleEvent<graphql.UpdateOnPush.Subscription> {

    public handle(e: EventFired<graphql.UpdateOnPush.Subscription>, ctx: HandlerContext): Promise<HandlerResult> {
        const push = e.data.Push[0];
        return restartClient({
            owner: push.repo.owner,
            repository: push.repo.name,
            branch: push.branch,
            sha: push.after.sha,
            teamId: ctx.teamId,
        });
    }
}
