#!/usr/bin/env node
// Fetch subagent .md files from a GitHub repo or local folder into ~/.cursor/agents.
//
// Files this script installed are updated when upstream changes, unless you
// edited them locally. Files it did not install are never overwritten.
//
//   scripts/install-agents.mjs owner/repo
//   scripts/install-agents.mjs owner/repo --agent reviewer --agent opener
//   scripts/install-agents.mjs ./path/to/agents --list

import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  renameSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { createInterface } from "node:readline/promises";
import { stdin, stdout } from "node:process";

const DEFAULT_PATH = ".ai/agents";
const DEFAULT_DEST = join(homedir(), ".cursor", "agents");
const LOCK_NAME = ".install-agents-lock.json";

function usage(exitCode = 1) {
  console.log(`Usage:
  install-agents.mjs <owner/repo|local-dir> [options]

Options:
  --path <dir>     Remote directory (default: ${DEFAULT_PATH})
  --dest <dir>     Destination (default: ${DEFAULT_DEST})
  --ref <ref>      Git ref for GitHub sources
  --agent <name>   Install or update this agent (repeatable; filename without .md)
  --all            Install or update every remote agent this script is allowed to touch
  --list           List remote agents and local status
  -h, --help       Show this help

Untracked local files are never overwritten. Tracked files update only if
you have not edited them since the last install.`);
  process.exit(exitCode);
}

function die(message) {
  console.error(`error: ${message}`);
  process.exit(1);
}

function sha256(buf) {
  return createHash("sha256").update(buf).digest("hex");
}

function parseArgs(argv) {
  const opts = {
    source: null,
    path: null,
    dest: DEFAULT_DEST,
    ref: null,
    agents: [],
    all: false,
    list: false,
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const next = () => {
      const value = argv[++i];
      if (value == null || value.startsWith("-")) {
        die(`${arg} needs a value`);
      }
      return value;
    };

    if (arg === "-h" || arg === "--help") usage(0);
    else if (arg === "--path") opts.path = next();
    else if (arg === "--dest") opts.dest = resolve(next());
    else if (arg === "--ref") opts.ref = next();
    else if (arg === "--agent") opts.agents.push(next().replace(/\.md$/, ""));
    else if (arg === "--all") opts.all = true;
    else if (arg === "--list") opts.list = true;
    else if (arg.startsWith("-")) die(`unknown option ${arg}`);
    else if (!opts.source) opts.source = arg;
    else die(`unexpected argument ${arg}`);
  }

  if (!opts.source) usage();
  return opts;
}

function parseSource(raw, pathFlag, refFlag) {
  if (existsSync(raw) && statSync(raw).isDirectory()) {
    const dir = resolve(raw);
    const mdHere = readdirSync(dir).some((name) => name.endsWith(".md"));
    if (mdHere && !pathFlag) {
      return { kind: "local", dir };
    }
    return { kind: "local", dir: join(dir, pathFlag || DEFAULT_PATH) };
  }

  const url = raw.match(
    /^https?:\/\/github\.com\/([^/]+)\/([^/]+?)(?:\.git)?(?:\/tree\/([^/]+)(?:\/(.*))?)?$/,
  );
  if (url) {
    return {
      kind: "github",
      owner: url[1],
      repo: url[2],
      ref: refFlag || url[3] || null,
      path: pathFlag || url[4] || DEFAULT_PATH,
    };
  }

  const parts = raw.replace(/\.git$/, "").split("/").filter(Boolean);
  if (parts.length >= 2 && !raw.startsWith(".") && !raw.startsWith("/")) {
    return {
      kind: "github",
      owner: parts[0],
      repo: parts[1],
      ref: refFlag,
      path: pathFlag || parts.slice(2).join("/") || DEFAULT_PATH,
    };
  }

  die(`cannot parse source: ${raw}`);
}

function sourceKey(source) {
  if (source.kind === "local") return `local:${source.dir}`;
  return `github:${source.owner}/${source.repo}:${source.path}${source.ref ? `@${source.ref}` : ""}`;
}

function ghApi(endpoint) {
  const result = spawnSync("gh", ["api", endpoint], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  if (result.status !== 0) {
    die(`gh api ${endpoint}\n${result.stderr || result.stdout || "failed"}`);
  }
  return JSON.parse(result.stdout);
}

function listLocal(dir) {
  if (!existsSync(dir) || !statSync(dir).isDirectory()) {
    die(`local path not found: ${dir}`);
  }
  return readdirSync(dir)
    .filter((name) => name.endsWith(".md") && statSync(join(dir, name)).isFile())
    .sort()
    .map((name) => ({
      name: name.replace(/\.md$/, ""),
      file: name,
      read: () => readFileSync(join(dir, name)),
    }));
}

function listGithub({ owner, repo, path, ref }) {
  let endpoint = `repos/${owner}/${repo}/contents/${path}`;
  if (ref) endpoint += `?ref=${encodeURIComponent(ref)}`;

  const payload = ghApi(endpoint);
  if (!Array.isArray(payload)) {
    die(`${owner}/${repo}:${path} is not a directory`);
  }

  return payload
    .filter((item) => item.type === "file" && item.name.endsWith(".md"))
    .sort((a, b) => a.name.localeCompare(b.name))
    .map((item) => ({
      name: item.name.replace(/\.md$/, ""),
      file: item.name,
      read() {
        let fileEndpoint = `repos/${owner}/${repo}/contents/${item.path}`;
        if (ref) fileEndpoint += `?ref=${encodeURIComponent(ref)}`;
        const body = ghApi(fileEndpoint);
        if (body.encoding !== "base64" || typeof body.content !== "string") {
          die(`could not read ${item.path}`);
        }
        return Buffer.from(body.content.replace(/\n/g, ""), "base64");
      },
    }));
}

function lockPath(destDir) {
  return join(destDir, LOCK_NAME);
}

function loadLock(destDir) {
  const file = lockPath(destDir);
  if (!existsSync(file)) return { version: 1, agents: {} };
  try {
    const parsed = JSON.parse(readFileSync(file, "utf8"));
    if (!parsed || typeof parsed !== "object" || typeof parsed.agents !== "object") {
      return { version: 1, agents: {} };
    }
    return { version: 1, agents: parsed.agents };
  } catch {
    return { version: 1, agents: {} };
  }
}

function saveLock(destDir, lock) {
  mkdirSync(destDir, { recursive: true });
  const file = lockPath(destDir);
  const tmp = `${file}.${process.pid}.tmp`;
  writeFileSync(tmp, JSON.stringify(lock, null, 2) + "\n");
  renameSync(tmp, file);
}

function classify(destDir, item, lock, origin, remoteHash) {
  const dest = join(destDir, item.file);
  const record = lock.agents[item.file];
  if (!existsSync(dest)) return { status: "new", remoteHash };

  const localHash = sha256(readFileSync(dest));
  if (!record) return { status: "unmanaged", remoteHash, localHash };
  if (record.source !== origin) return { status: "other-source", remoteHash, localHash };
  if (localHash !== record.sha256) return { status: "edited", remoteHash, localHash };
  if (remoteHash !== record.sha256) return { status: "outdated", remoteHash, localHash };
  return { status: "current", remoteHash, localHash };
}

const STATUS_LABEL = {
  new: "new",
  outdated: "outdated (will update)",
  current: "current",
  edited: "locally edited (will skip)",
  unmanaged: "already present (will skip)",
  "other-source": "installed from another source (will skip)",
};

function printCatalog(items, destDir, lock, origin) {
  if (items.length === 0) {
    console.log("no .md agents found");
    return;
  }
  for (const item of items) {
    const info = classify(destDir, item, lock, origin, sha256(item.read()));
    console.log(`  ${item.name.padEnd(28)} ${STATUS_LABEL[info.status]}`);
  }
}

function applyItem(destDir, item, lock, origin) {
  const remote = item.read();
  const remoteHash = sha256(remote);
  const info = classify(destDir, item, lock, origin, remoteHash);
  const dest = join(destDir, item.file);

  if (info.status === "current") return "current";
  if (info.status === "edited") return "edited";
  if (info.status === "unmanaged") return "unmanaged";
  if (info.status === "other-source") return "other-source";

  mkdirSync(destDir, { recursive: true });
  const tmp = `${dest}.${process.pid}.tmp`;
  writeFileSync(tmp, remote);
  renameSync(tmp, dest);

  const now = new Date().toISOString();
  lock.agents[item.file] = {
    source: origin,
    sha256: remoteHash,
    installedAt: lock.agents[item.file]?.installedAt || now,
    updatedAt: now,
  };
  return info.status === "outdated" ? "updated" : "installed";
}

function resolveSelection(items, names) {
  const wanted = new Set(names);
  const unknown = [...wanted].filter((name) => !items.some((item) => item.name === name));
  if (unknown.length) {
    die(`unknown agent: ${unknown.join(", ")}`);
  }
  return items.filter((item) => wanted.has(item.name));
}

async function promptSelection(items, destDir, lock, origin) {
  if (!stdin.isTTY || !stdout.isTTY) {
    die("no TTY; pass --agent <name>, --all, or --list");
  }

  console.log("");
  items.forEach((item, index) => {
    const info = classify(destDir, item, lock, origin, sha256(item.read()));
    console.log(`  ${String(index + 1).padStart(2)}  ${item.name}  ${STATUS_LABEL[info.status]}`);
  });
  console.log("");

  const rl = createInterface({ input: stdin, output: stdout });
  const answer = (await rl.question('Which? numbers, names, "all", or empty to cancel: ')).trim();
  rl.close();

  if (!answer) return [];
  if (answer.toLowerCase() === "all") return items;

  const picked = [];
  for (const token of answer.split(/[\s,]+/).filter(Boolean)) {
    if (/^\d+$/.test(token)) {
      const item = items[Number(token) - 1];
      if (!item) die(`no agent numbered ${token}`);
      picked.push(item);
    } else {
      const name = token.replace(/\.md$/, "");
      const item = items.find((candidate) => candidate.name === name);
      if (!item) die(`unknown agent: ${name}`);
      picked.push(item);
    }
  }
  return picked;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const source = parseSource(opts.source, opts.path, opts.ref);
  const destDir = opts.dest;
  const origin = sourceKey(source);
  const lock = loadLock(destDir);

  const items =
    source.kind === "local"
      ? listLocal(source.dir)
      : listGithub(source);

  const label =
    source.kind === "local"
      ? source.dir
      : `${source.owner}/${source.repo}:${source.path}${source.ref ? `@${source.ref}` : ""}`;

  console.log(`${label}  →  ${destDir}`);

  if (opts.list) {
    printCatalog(items, destDir, lock, origin);
    return;
  }

  let selected;
  if (opts.agents.length) selected = resolveSelection(items, opts.agents);
  else if (opts.all) selected = items;
  else selected = await promptSelection(items, destDir, lock, origin);

  if (selected.length === 0) {
    console.log("nothing to install");
    return;
  }

  const counts = { installed: 0, updated: 0, current: 0, skipped: 0 };
  for (const item of selected) {
    const result = applyItem(destDir, item, lock, origin);
    if (result === "installed") {
      counts.installed += 1;
      console.log(`installed ${item.file}`);
    } else if (result === "updated") {
      counts.updated += 1;
      console.log(`updated ${item.file}`);
    } else if (result === "current") {
      counts.current += 1;
      console.log(`current ${item.file}`);
    } else if (result === "edited") {
      counts.skipped += 1;
      console.log(`skipped ${item.file} (locally edited)`);
    } else if (result === "other-source") {
      counts.skipped += 1;
      console.log(`skipped ${item.file} (installed from another source)`);
    } else {
      counts.skipped += 1;
      console.log(`skipped ${item.file} (already exists)`);
    }
  }
  saveLock(destDir, lock);
  console.log(
    `done  installed=${counts.installed}  updated=${counts.updated}  current=${counts.current}  skipped=${counts.skipped}`,
  );
}

main().catch((error) => {
  die(error instanceof Error ? error.message : String(error));
});
