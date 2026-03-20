// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

//////////////////////////////////////////////////////////////////////////////
// Reads the Node.js package version from the package.json file
// and writes it as the Cannon package version of the cannonfile.toml file.
// This script is meant to be run in the project root and after running
// `changeset version`, which updates the Node.js package version.
//////////////////////////////////////////////////////////////////////////////

import fs from 'node:fs';
import path from 'node:path';

// Resolve paths to package.json and cannonfile.toml
const packageJsonPath = path.resolve(process.cwd(), 'package.json');
const cannonfilePath = path.resolve(process.cwd(), 'cannonfile.toml');

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

// Check if cannonfile.toml exists
if (!fs.existsSync(cannonfilePath)) {
    console.error(`Error: ${cannonfilePath} not found.`);
    process.exit(1);
}

// Read cannonfile.toml
const cannonfileContent = fs.readFileSync(cannonfilePath, 'utf8');

// Create a RegExp to match the version TOML key/value pair
const versionTomlKvPairRegExp = /^\s*(?:version|"version"|'version')\s*=.*$/m;

// Check if the RegExp matches any occurence in Cannonfile content
if (cannonfileContent.match(versionTomlKvPairRegExp) === null) {
    console.error("Error: No 'version' key/value pair in cannonfile.toml.");
    process.exit(1);
}

// Build the version key/value pair
const versionTomlKvPair = `version = "${nodeJsPackageVersion}"`;

// Replace version key/value pair in Cannonfile content
const newCannonfileContent = cannonfileContent
    .replace(versionTomlKvPairRegExp, versionTomlKvPair);

// Skip updating Cannonfile if already in-sync
if (cannonfileContent == newCannonfileContent) {
    console.log("Cannonfile version is already in-sync.");
} else {
    fs.writeFileSync(cannonfilePath, newCannonfileContent, 'utf8');
    console.log(`Updated Cannonfile version to ${nodeJsPackageVersion}`);
}
