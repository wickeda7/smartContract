const { frontEndContractsFile, frontEndAbiLocation } = require("../helper-hardhat-config")
require("dotenv").config()
const fs = require("fs")
const { network } = require("hardhat")

module.exports = async () => {
    if (process.env.UPDATE_FRONT_END) {
        console.log("Writing to front end...")
        // await updateContractAddresses()
        await updateAbi()
        console.log("Front end written!")
    }
}

async function updateAbi() {
    const nftMarketplace = await ethers.getContract("NftMarketplace")
    try {
        fs.writeFileSync(
            frontEndAbiLocation,
            nftMarketplace.interface.format(ethers.utils.FormatTypes.json)
        )
    } catch (error) {
        console.log(error)
    }
}

async function updateContractAddresses() {
    const chainId = network.config.chainId.toString()
    const nftMarketplace = await ethers.getContract("NftMarketplace")
    const contractAddresses = JSON.parse(fs.readFileSync(frontEndContractsFile, "utf8"))
    if (chainId in contractAddresses) {
        if (!contractAddresses[chainId]["NftMarketplace"].includes(nftMarketplace.address)) {
            contractAddresses[chainId]["NftMarketplace"].push(nftMarketplace.address)
        }
    } else {
        contractAddresses[chainId] = { NftMarketplace: [nftMarketplace.address] }
    }
    try {
        fs.writeFileSync(frontEndContractsFile, JSON.stringify(contractAddresses))
    } catch (error) {
        console.log(error)
    }
}
module.exports.tags = ["all", "frontend"]
