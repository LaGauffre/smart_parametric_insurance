// const ReserveProviderToken = artifacts.require("ReserveProviderToken");
const ParametricInsurance = artifacts.require("ParametricInsurance");

module.exports = async function(deployer) {
  // Deploy the ReserveProviderToken contract
  await deployer.deploy(ParametricInsurance);

  // Deploy the ParametricInsurance contract with the address of the deployed ReserveProviderToken
  // await deployer.deploy(ParametricInsurance, reserveProviderTokenInstance.address);
};
