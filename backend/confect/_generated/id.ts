import { GenericId } from "@confect/core";

export type TableNames = "bootstrapEvents";

export const Id = <const TableName extends TableNames>(
  tableName: TableName,
) => GenericId.GenericId(tableName);
