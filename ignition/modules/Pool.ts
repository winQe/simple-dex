import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import hre from "hardhat";

export default buildModule("Pool", (m) => {
  const initialAbcWei = hre.ethers.parseEther("1000000"); // Initial supply is 1 million
  const abcToken = m.contract("ABCToken", [initialAbcWei]);

  const initialDefWei = hre.ethers.parseEther("5000000"); // Initial supply is 5 million
  const defToken = m.contract("DEFToken", [initialDefWei]);

  const pool = m.contract("Pool", [abcToken, defToken]);

  return { pool };
});
