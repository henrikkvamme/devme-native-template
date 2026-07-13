import { RegisteredConvexFunction, RegisteredFunctions } from "@confect/server";
import databaseSchema from "../schema";
import bootstrap from "../../bootstrap.impl";

export default RegisteredFunctions.buildForGroup<typeof import("../../bootstrap.spec")["default"]>(databaseSchema, bootstrap, RegisteredConvexFunction.make);
