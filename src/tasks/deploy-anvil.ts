import { spawn } from "child_process";
import fs from "fs";
import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import path from "path";

export interface DeployOptions {
    dumpFile: string;
    exportFile?: string;
    silent: boolean;
}

const deploy = async (
    taskArgs: DeployOptions,
    hre: HardhatRuntimeEnvironment,
) => {
    const { dumpFile, silent } = taskArgs;
    const exportFile =
        taskArgs.exportFile ?? `export/abi/${hre.network.name}.json`;

    // make sure directories exist
    fs.mkdirSync(path.dirname(dumpFile), { recursive: true });
    fs.mkdirSync(path.dirname(exportFile), { recursive: true });

    // run anvil
    const args = ["--dump-state", dumpFile];
    if (silent) {
        args.push("--silent");
    }
    const anvil = spawn("anvil", args, { stdio: "inherit" });

    try {
        // run deployment
        console.log(`deploying to anvil and dumping state to ${dumpFile}`);
        await hre.run("deploy", {
            export: exportFile,
            reset: true,
            silent,
        });
    } finally {
        // kill anvil
        anvil.kill();
    }
};

task("deploy-anvil", "Deploys to anvil and dump state")
    .addParam<string>(
        "dumpFile",
        "anvil state dump file",
        "state.json",
        types.string,
    )
    .addOptionalParam<string>(
        "exportFile",
        "hardhat-deploy export file",
        undefined,
        types.string,
    )
    .addFlag("silent", "do not print any log")
    .setAction(deploy);
