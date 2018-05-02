# truffle console --network ganache
> migrate --compile-all --reset
> OreOreCoin1.address
> web3.eth.getBalance(web3.eth.accounts[0]).toNumber()
> OreOreCoin1.deployed().then(function(instance) {app=instance;} )
> app.transfer(web3.eth.accounts[1], "1000")
