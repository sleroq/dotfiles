#!/usr/bin/env bun
import { $ } from "bun";
import { appendFile } from "node:fs/promises";

type Release = {
  tag_name: string;
  draft: boolean;
  prerelease: boolean;
  assets: { name: string }[];
};

type VersionedRelease = Release & { version: string };
type BaseConfig = { repo: string };
type StableConfig = BaseConfig & { prefix: string };
type BinaryConfig = BaseConfig & { assets: (version: string) => string[] };
type PlatformConfig = BaseConfig & {
  assetPrefix: (version: string) => string;
  platforms: string[];
};
type Metadata = { version: string; [key: string]: string | Record<string, string> };

type Strategy<T extends BaseConfig> = T & {
  release: (config: T, packageName: string) => Promise<VersionedRelease>;
  update: (config: T, packageName: string, release: VersionedRelease) => Promise<void>;
};

function packageStrategy<T extends BaseConfig>(config: Strategy<T>) {
  return async (packageName: string) => {
    const release = await config.release(config, packageName);
    await config.update(config, packageName, release);
  };
}

const packages = {
  helium: packageStrategy({
    repo: "imputnet/helium-linux",
    release: latestGithubRelease,
    update: singleBinary,
    assets: (version: string) => [`helium-${version}-x86_64.AppImage`],
  }),
  "trusttunnel-client": packageStrategy<StableConfig & PlatformConfig>({
    repo: "TrustTunnel/TrustTunnelClient",
    prefix: "v",
    release: latestStableRelease,
    update: platformAssets,
    assetPrefix: (version: string) => `trusttunnel_client-v${version}-`,
    platforms: ["linux-x86_64", "linux-aarch64", "macos-universal"],
  }),
  rift: packageStrategy<StableConfig & PlatformConfig>({
    repo: "anomalyco/rift",
    prefix: "v",
    release: latestStableRelease,
    update: platformAssets,
    assetPrefix: (version: string) => `rift-v${version}-`,
    platforms: ["x86_64-unknown-linux-gnu", "aarch64-apple-darwin", "x86_64-apple-darwin"],
  }),
  "moq-relay": packageStrategy<StableConfig & BinaryConfig>({
    repo: "moq-dev/moq",
    prefix: "moq-relay-v",
    release: latestStableRelease,
    update: singleBinary,
    assets: (version: string) => [`moq-relay-v${version}-x86_64-unknown-linux-gnu`],
  }),
  "obs-moq": packageStrategy<StableConfig & BinaryConfig>({
    repo: "moq-dev/moq",
    prefix: "libmoq-v",
    release: latestStableRelease,
    update: obsSourceAndLibmoq,
    assets: (version: string) => [`moq-${version}-x86_64-unknown-linux-gnu.tar.gz`],
  }),
  svelte: packageStrategy({
    repo: "themixednuts/tree-sitter-htmlx",
    prefix: "v",
    release: latestStableRelease,
    update: svelteCommitSource,
  }),
};

function compareVersions(a: string, b: string) {
  const left = a.split(".").map(BigInt);
  const right = b.split(".").map(BigInt);
  for (let i = 0; i < Math.min(left.length, right.length); i++) {
    if (left[i] !== right[i]) return left[i] < right[i] ? -1 : 1;
  }
  return left.length - right.length;
}

async function latestGithubRelease({ repo }: BaseConfig) {
  const release: Release = await $`gh api ${`repos/${repo}/releases/latest`}`.json();
  if (!/^[0-9]+(\.[0-9]+)*$/.test(release.tag_name)) {
    throw new Error(`Unexpected release version: ${release.tag_name}`);
  }
  return { ...release, version: release.tag_name };
}

async function latestStableRelease({ repo, prefix }: StableConfig, packageName: string) {
  const pages: Release[][] = await $`gh api --paginate --slurp ${`repos/${repo}/releases?per_page=100`}`.json();
  const releases = pages.flat().filter((release) =>
    release.draft === false && release.prerelease === false &&
    release.tag_name.startsWith(prefix) && /^[0-9]+(\.[0-9]+)*$/.test(release.tag_name.slice(prefix.length)),
  ).map((release) => ({ ...release, version: release.tag_name.slice(prefix.length) }));
  releases.sort((a, b) => compareVersions(a.version, b.version));
  if (!releases.length) throw new Error(`No stable matching release for ${packageName}`);
  return releases[releases.length - 1];
}

async function prefetch(url: string, unpack = false) {
  const hash = (await $`nix-prefetch-url ${unpack ? ["--unpack"] : []} ${url}`.text()).trim();
  return (await $`nix hash convert --hash-algo sha256 --to sri ${hash}`.text()).trim();
}

async function writeUpdate(file: string, metadata: Metadata) {
  await Bun.write(file, `${JSON.stringify(metadata, null, 2)}\n`);
  const output = process.env.GITHUB_OUTPUT;
  if (!output) throw new Error("GITHUB_OUTPUT is not set");
  await appendFile(output, "changed=true\n");
}

async function updateAssets(config: BaseConfig, packageName: string, release: VersionedRelease, assets: string[], metadata: (base: string) => Promise<Metadata>) {
  const { repo } = config;
  const { version, tag_name: tag } = release;
  for (const asset of assets) {
    if (!release.assets.some((item) => item.name === asset)) throw new Error(`Missing asset ${asset} in ${repo} ${tag}`);
  }

  const file = `packages/${packageName}.json`;
  if (version === (await Bun.file(file).json()).version) {
    console.log(`${packageName} ${version} is already current`);
    return;
  }

  const base = `https://github.com/${repo}/releases/download/${tag}`;
  await writeUpdate(file, await metadata(base));
}

function singleBinary(config: BinaryConfig, packageName: string, release: VersionedRelease) {
  const assets = config.assets(release.version);
  return updateAssets(config, packageName, release, assets, async (base) => ({
    version: release.version,
    hash: await prefetch(`${base}/${assets[0]}`),
  }));
}

function platformAssets(config: PlatformConfig, packageName: string, release: VersionedRelease) {
  const prefix = config.assetPrefix(release.version);
  const assets = config.platforms.map((platform) => `${prefix}${platform}.tar.gz`);
  return updateAssets(config, packageName, release, assets, async (base) => {
    const hashes: Record<string, string> = {};
    for (const asset of assets) {
      hashes[asset.slice(prefix.length, -".tar.gz".length)] = await prefetch(`${base}/${asset}`);
    }
    return { version: release.version, hashes };
  });
}

function obsSourceAndLibmoq(config: BinaryConfig, packageName: string, release: VersionedRelease) {
  const assets = config.assets(release.version);
  return updateAssets(config, packageName, release, assets, async (base) => ({
    version: release.version,
    sourceHash: await prefetch(`https://github.com/${config.repo}/archive/refs/tags/${release.tag_name}.tar.gz`, true),
    libmoqHash: await prefetch(`${base}/${assets[0]}`, true),
  }));
}

async function svelteCommitSource(config: BaseConfig, packageName: string, release: VersionedRelease) {
  const { repo } = config;
  const { version, tag_name: tag } = release;
  const file = "home/config/ast-grep/svelte-parser.json";
  const pin = await Bun.file(file).json();
  const { sha: rev } = await $`gh api ${`repos/${repo}/commits/${tag}`}`.json();
  if (!/^[0-9a-f]{40}$/.test(rev)) throw new Error(`Invalid commit SHA for ${repo} ${tag}`);
  if (version === pin.version && rev === pin.rev) {
    console.log(`${packageName} ${version} is already current`);
    return;
  }
  const hash = await prefetch(`https://github.com/${repo}/archive/${rev}.tar.gz`, true);
  await writeUpdate(file, { ...pin, rev, hash, version });
}

async function main() {
  const packageName = process.argv[2];
  const config = Object.entries(packages).find(([name]) => name === packageName)?.[1];
  if (!config) throw new Error(`Unknown package: ${packageName}`);

  await config(packageName);
}

await main();
