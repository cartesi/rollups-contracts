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
if (!nodeJsPackageVersion) {
    console.error("Error: No 'version' field found in package.json.");
    process.exit(1);
}

// Check if cannonfile.toml exists
if (!fs.existsSync(cannonfilePath)) {
    console.error(`Error: ${cannonfilePath} not found.`);
    process.exit(1);
}

// Read cannonfile.toml
const cannonfileContent = fs.readFileSync(cannonfilePath, 'utf8');

// Create a Regexp to match the version TOML expression
const versionRegexp = /^[ \t]*(version|"version"|'version')[ \t]*=.*$/m;

// Check if the Regexp matches any occurence in Cannonfile content
if (cannonfileContent.match(versionRegexp) === null) {
    console.error("Error: No 'version' expression found in cannonfile.toml.");
    process.exit(1);
}

// Build version replacement string
const versionReplacement = `version = "${nodeJsPackageVersion}"`;

// Replace version expression in Cannonfile content
const newCannonfileContent = cannonfileContent.replace(versionRegexp, versionReplacement);

// Exit successfully if Cannonfile is already in-sync
if (cannonfileContent == newCannonfileContent) {
    console.log("Cannonfile is already in-sync with the Node.js package.")
    process.exit(0);
}

// Update cannonfile.toml with new content
fs.writeFileSync(cannonfilePath, newCannonfileContent, 'utf8');

console.log(`Updated Cannonfile version to ${nodeJsPackageVersion}`);
