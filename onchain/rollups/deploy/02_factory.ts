// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, DeployOptions } from "hardhat-deploy/types";
import { deployENS, ENS } from "@ethereum-waffle/ens";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

const deployEns = async (deployer: SignerWithAddress) => {
    const ens = await deployENS(deployer);
    await ens.createTopLevelDomain("test");
    return ens.ens.address;
};

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers, network } = hre;
    const { deployer } = await getNamedAccounts();
    const [deployerSigner] = await ethers.getSigners();

    // IoTeX doesn't have support yet, see https://github.com/safe-global/safe-singleton-factory/issues/199
    // Chiado is not working, see https://github.com/safe-global/safe-singleton-factory/issues/201
    const nonDeterministicNetworks = ["iotex_testnet", "chiado"];
    const deterministicDeployment = !nonDeterministicNetworks.includes(
        network.name,
    );

    const opts: DeployOptions = {
        deterministicDeployment,
        from: deployer,
        log: true,
    };

    const { Bitmask, MerkleV2 } = await deployments.all();

    // ENS
    const provider = ethers.getDefaultProvider();
    const ensAddress = provider.network.ensAddress || deployEns(deployerSigner);

    await deployments.deploy("CartesiDAppFactory", {
        ...opts,
        args: [ensAddress],
        libraries: {
            Bitmask: Bitmask.address,
            MerkleV2: MerkleV2.address,
        },
    });
};

export default func;
func.tags = ["Factory"];
