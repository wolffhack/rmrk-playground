import { ethers, run, network } from 'hardhat';
import { BigNumber } from 'ethers';
import { rotam } from '../typechain-types';
import { getRegistry } from './getRegistry';


async function main() {
  await deployContracts();
}

async function deployContracts(): Promise<void> {
  console.log(`Deploying rotam to ${network.name} blockchain...`);

  const contractFactory = await ethers.getContractFactory("rotam");
  const args = [
    "www.rotam.io",
    BigNumber.from(100),
    "0x387188e2884569992627444b16f4c1A72C88EC81",
    300,
  ] as const;
  
  const contract: rotam = await contractFactory.deploy(...args);
  await contract.deployed();
  console.log(`rotam deployed to ${contract.address}.`);

  // Only do on testing, or if whitelisted for production
  const registry = await getRegistry();
  await registry.addExternalCollection(contract.address, args[0]);
  console.log('Collection added to Singular Registry');

  const chainId = (await ethers.provider.getNetwork()).chainId;
  if (chainId === 31337) {
    console.log('Skipping verify on local chain');
    return;
  }

  await run('verify:verify', {
    address: contract.address,
    constructorArguments: args,
    contract: 'contracts/MultiAsset.sol:rotam',
  });

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
