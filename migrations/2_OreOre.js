var OreOreCoin = artifacts.require("./OreOreCoin.sol");

// constructor(uint256 _supply, string _name, string _symbol, uint8 _decimals) public {
module.exports = function(deployer) {
  deployer.deploy(OreOreCoin, 10000, "gogo", "oc", 0);
};
