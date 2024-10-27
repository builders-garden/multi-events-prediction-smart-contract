import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";
dotenv.config();

const providerApiKey = process.env.PROVIDER_API_KEY;

const config: HardhatUserConfig = {
  solidity: "0.8.27",
  networks: {
    hardhat: {
      forking: {
        url: `https://base-mainnet.infura.io/v3/${providerApiKey}`,
      },
    },
  },
};

export default config;
