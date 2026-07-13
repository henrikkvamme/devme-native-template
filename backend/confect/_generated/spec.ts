import { GroupSpec, Spec } from "@confect/core";
import bootstrap from "../bootstrap.spec";

const spec: Spec.Spec<
  | GroupSpec.NamedAt<typeof bootstrap, "bootstrap">
> = Spec.make().addAt("bootstrap", bootstrap);

export default spec;
