import { defineConfig } from "vite-plus";

export default defineConfig({
  fmt: {
    ignorePatterns: [
      "apps/**",
      "backend/confect/_generated/**",
      "backend/convex/_generated/**",
      "contracts/function-spec.json",
    ],
    semi: true,
  },
  lint: {
    ignorePatterns: [
      "apps/**",
      "backend/confect/_generated/**",
      "backend/convex/_generated/**",
      "features/**",
    ],
    options: {
      typeAware: true,
      typeCheck: true,
    },
  },
  staged: {
    "*.{js,json,ts}": ["vp fmt", "vp lint"],
  },
  test: {
    include: ["backend/**/*.test.ts", "tooling/**/*.test.ts"],
  },
});
