// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

//////////////////////////////////////////////////////////////////////////////
// Deploys the smart contracts to an Anvil devnet and dumps its state
// into a JSON file with all historical states preserved.
//////////////////////////////////////////////////////////////////////////////

import childProcess from 'node:child_process';
import http from 'node:http';

console.log("🚧 Spawning Anvil...");

const anvilChildProcess = childProcess.spawn(
    'anvil',
    [
        '--dump-state',
        'state.json',
        '--preserve-historical-states',
        '--quiet',
    ],
    {
        stdio: [
            'ignore',
            'inherit',
            'inherit',
        ],
    }
);

console.log("✅ Anvil spawned!");

function killAnvilChildProcess() {
    console.log("🚧 Killing Anvil...");
    anvilChildProcess.kill();
}

process.on('SIGINT', killAnvilChildProcess);
process.on('SIGTERM', killAnvilChildProcess);

async function waitForAnvil(url = 'http://127.0.0.1:8545', retries = 20, delay = 500) {
    const { hostname, port, pathname } = new URL(url);

    const pingAnvil = () =>
        new Promise((resolve, reject) => {
            const req = http.request(
                {
                    hostname,
                    port,
                    path: pathname,
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                },
                (res) => {
                    res.on('data', () => {}); // consume data
                    res.on('end', resolve);
                }
            );
            req.on('error', reject);
            req.write(JSON.stringify({
                jsonrpc: '2.0',
                method: 'eth_chainId',
                id: 1,
            }));
            req.end();
        });

    for (let i = 0; i < retries; i++) {
        try {
            console.log("🚧 Pinging Anvil...");
            await pingAnvil();
            return true;
        } catch {
            console.log(`🚧 Anvil is not listening yet. Waiting ${delay} ms...`)
            await new Promise(r => setTimeout(r, delay));
        }
    }

    killAnvilChildProcess();
    return false;
}

const anvilIsListening = await waitForAnvil();

if (!anvilIsListening) {
    console.error('❌ Anvil spawn failed');
    killAnvilChildProcess();
    process.exit(1);
}

console.log("✅ Anvil is listening!")

function deployToDevnet(name, cannonfile) {
    console.log(`🚧 Building Cannon package ${name}...`)

    try {
        const command = "cannon";
        const args = [
            "build",
            cannonfile,
            "--private-key",
            "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
            "--rpc-url",
            "http://127.0.0.1:8545",
            "--wipe",
            "--write-deployments",
            "deployments",
        ]
        childProcess.execSync(
            ([command, ...args]).join(" "),
            { stdio: 'inherit' }
        );
    } catch (err) {
        console.error(`❌ Cannon package ${name} build failed: ${err.message}`);
        killAnvilChildProcess();
        process.exit(1);
    }

    console.log(`✅ Cannon package ${name} built successfully!`);
}

deployToDevnet("cartesi-rollups", "cannonfile.toml");

killAnvilChildProcess();
