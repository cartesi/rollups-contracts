// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

//////////////////////////////////////////////////////////////////////////////
// Reads the Node.js package version from the package.json file
// and updates the cannonfile.toml and RollupsContract.sol files.
// This script is meant to be run in the project root and after running
// `changeset version`, which updates the Node.js package version.
//////////////////////////////////////////////////////////////////////////////

import fs from 'node:fs';
import path from 'node:path';

// Resolve paths to package.json and cannonfile.toml
const packageJsonPath = path.resolve(process.cwd(), 'package.json');
const cannonfilePath = path.resolve(process.cwd(), 'cannonfile.toml');

// Resolve path to base contract that defines the project version
const contractName = 'RollupsContract';
const contractFileName = contractName + '.sol';
const contractDirPath = path.resolve(process.cwd(), 'src', 'common');
const contractFilePath = path.resolve(contractDirPath, contractFileName);

// Check if package.json exists
if (!fs.existsSync(packageJsonPath)) {
    console.error(`Error: ${packageJsonPath} not found.`);
    process.exit(1);
}

// Read and parse package.json
const nodeJsPackage = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));

// Extract version from Node.js package
const nodeJsPackageVersion = nodeJsPackage.version;

// Check whether the package version is defined
if (typeof nodeJsPackageVersion === 'undefined') {
    console.error("Error: The package version is undefined");
    process.exit(1);
}

// Check whether the package version is a string
if (typeof nodeJsPackageVersion !== 'string') {
    console.error("Error: The package version is not a string.");
    process.exit(1);
}

// Create a RegExp that matches semantic version strings
const semVerRegExp = /^(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)(?:-(?<preRelease>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+(?<buildMetadata>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/;

// Check if the Node.js package version string is a valid semantic version string
const versionMatch = nodeJsPackageVersion.match(semVerRegExp);
if (versionMatch === null) {
    console.error(`Error: The package version ${nodeJsPackageVersion} is not valid.`);
    process.exit(1);
}

// Extract the semantic version parts from the RegExp match
const {major, minor, patch, preRelease, buildMetadata} = versionMatch.groups;

// Reassamble the original string from its constituent parts
const reassambledVersion = `${major}.${minor}.${patch}`
    + (typeof preRelease    === 'undefined' ? "" : `-${preRelease}`)
    + (typeof buildMetadata === 'undefined' ? "" : `+${buildMetadata}`);

// Check that assembling the semantic version parts yields the original string
if (nodeJsPackageVersion !== reassambledVersion) {
    console.error(`Error: Failed to correctly parse version ${nodeJsPackageVersion}.`);
    console.error(`Reassambled version string ${reassambledVersion} differs from original.`);
    process.exit(1);
}

// Read version contract
const contractContent = fs.readFileSync(contractFilePath, 'utf8');

// Create a RegExp to match the major version assignment statement
const majorAssignmentStatementRegExp = /^(?<lhs>\s*major)\s*=.*$/m;

// Check if the RegExp matches any occurence in contract content
if (contractContent.match(majorAssignmentStatementRegExp) == null) {
    console.error(`Error: No 'major' assignment statement in ${contractName}.`);
    process.exit(1);
}

// Build the major version assignment statement
const majorAssignmentStatement = `$<lhs> = ${major};`;

// Create a RegExp to match the minor version assignment statement
const minorAssignmentStatementRegExp = /^(?<lhs>\s*minor)\s*=.*$/m;

// Check if the RegExp matches any occurence in contract content
if (contractContent.match(minorAssignmentStatementRegExp) == null) {
    console.error(`Error: No 'minor' assignment statement in ${contractName}.`);
    process.exit(1);
}

// Build the minor version assignment statement
const minorAssignmentStatement = `$<lhs> = ${minor};`;

// Create a RegExp to match the patch version assignment statement
const patchAssignmentStatementRegExp = /^(?<lhs>\s*patch)\s*=.*$/m;

// Check if the RegExp matches any occurence in contract content
if (contractContent.match(patchAssignmentStatementRegExp) == null) {
    console.error(`Error: No 'patch' assignment statement in ${contractName}.`);
    process.exit(1);
}

// Build the patch version assignment statement
const patchAssignmentStatement = `$<lhs> = ${patch};`;

// Create a RegExp to match the pre-release version assignment statement
const preReleaseAssignmentStatementRegExp = /^(?<lhs>\s*preRelease)\s*=.*$/m;

// Check if the RegExp matches any occurence in contract content
if (contractContent.match(preReleaseAssignmentStatementRegExp) == null) {
    console.error(`Error: No 'preRelease' assignment statement in ${contractName}.`);
    process.exit(1);
}

// Build the pre-release version assignment statement
const preReleaseAssignmentStatement = `$<lhs> = "${preRelease ?? ""}";`;

// Create a RegExp to match the build metadata assignment statement
const buildMetadataAssignmentStatementRegExp = /^(?<lhs>\s*buildMetadata)\s*=.*$/m;

// Check if the RegExp matches any occurence in contract content
if (contractContent.match(buildMetadataAssignmentStatementRegExp) == null) {
    console.error(`Error: No 'buildMetadata' assignment statement in ${contractName}.`);
    process.exit(1);
}

// Build the build metadata assignment statement
const buildMetadataAssignmentStatement = `$<lhs> = "${buildMetadata ?? ""}";`;

// Replace version assignment statements in contract content
const newContractContent = contractContent
    .replace(majorAssignmentStatementRegExp, majorAssignmentStatement)
    .replace(minorAssignmentStatementRegExp, minorAssignmentStatement)
    .replace(patchAssignmentStatementRegExp, patchAssignmentStatement)
    .replace(preReleaseAssignmentStatementRegExp, preReleaseAssignmentStatement)
    .replace(buildMetadataAssignmentStatementRegExp, buildMetadataAssignmentStatement);

// Check if cannonfile.toml exists
if (!fs.existsSync(cannonfilePath)) {
    console.error(`Error: ${cannonfilePath} not found.`);
    process.exit(1);
}

// Read cannonfile.toml
const cannonfileContent = fs.readFileSync(cannonfilePath, 'utf8');

// Create a RegExp to match the version TOML key/value pair
const versionTomlKvPairRegExp = /^(?<lhs>\s*(?:version|"version"|'version'))\s*=.*$/m;

// Check if the RegExp matches any occurence in Cannonfile content
if (cannonfileContent.match(versionTomlKvPairRegExp) === null) {
    console.error("Error: No 'version' key/value pair in cannonfile.toml.");
    process.exit(1);
}

// Build the version key/value pair
const versionTomlKvPair = `$<lhs> = "${nodeJsPackageVersion}"`;

// Replace version key/value pair in Cannonfile content
const newCannonfileContent = cannonfileContent
    .replace(versionTomlKvPairRegExp, versionTomlKvPair);

//////////////////////////////////////////////////////////////////////////////
// After making all the necessary checks, we can now update the files.
// If the new contents match the current ones, we skip updating them.
//////////////////////////////////////////////////////////////////////////////

// Skip updating contracts version if already in-sync
if (contractContent == newContractContent) {
    console.log("Contracts version are already in-sync.");
} else {
    fs.writeFileSync(contractFilePath, newContractContent, 'utf8');
    console.log(`Updated contracts version to ${nodeJsPackageVersion}`);
}

// Skip updating Cannonfile if already in-sync
if (cannonfileContent == newCannonfileContent) {
    console.log("Cannonfile version is already in-sync.");
} else {
    fs.writeFileSync(cannonfilePath, newCannonfileContent, 'utf8');
    console.log(`Updated Cannonfile version to ${nodeJsPackageVersion}`);
}
