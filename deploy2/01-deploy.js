const main = async () => {
  const bitHoFactory = await hre.ethers.getContractFactory("BitHo");
  const bitHoContract = await bitHoFactory.deploy();
  await bitHoContract.deployed();
  console.log("BitHo deployed to:", bitHoContract.address);

  const bitToFactory = await hre.ethers.getContractFactory("BitTo");
  const bitToContract = await bitToFactory.deploy();
  await bitToContract.deployed();
  console.log("BitTo deployed to:", bitToContract.address);

  const flunaFactory = await hre.ethers.getContractFactory("Fluna");
  const flunaContract = await flunaFactory.deploy();
  await flunaContract.deployed();
  console.log("Fluna deployed to:", flunaContract.address);

  const scoinFactory = await hre.ethers.getContractFactory("Scoin");
  const scoinContract = await scoinFactory.deploy();
  await scoinContract.deployed();
  console.log("Scoin deployed to:", scoinContract.address);
};

(async () => {
  try {
    await main();
    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
})();
