// const ReserveProviderToken = artifacts.require("ReserveProviderToken");
// const CapitalRequirements = artifacts.require("CapitalRequirements");
// const InvestmentLogic = artifacts.require("InvestmentLogic");
const PricingLogic = artifacts.require("PricingLogic");
const InsuranceLogic = artifacts.require("InsuranceLogic"); 
const ModelPointsLogic = artifacts.require("ModelPointsLogic");


module.exports = async function(deployer) {

  await deployer.deploy(ModelPointsLogic);
  // Deploy the ReserveProviderToken contract
  await deployer.deploy(PricingLogic); // Example initial values for SCR and MCR

  // Get the deployed instance of CapitalRequirements
  const PricingLogics = await PricingLogic.deployed();
  const ModelPointsLogics = await ModelPointsLogic.deployed();

  // Deploy the InvestmentLogic contract with the address of CapitalRequirements
  await deployer.deploy(InsuranceLogic, PricingLogics.address, ModelPointsLogics.address);
  // await deployer.deploy(InvestmentLogic);

};
