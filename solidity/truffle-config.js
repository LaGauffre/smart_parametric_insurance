module.exports = {
  // networks: {
  //   development: {
  //     host: "localhost",
  //     port: 8545,
  //     network_id: "*", // Match any network id
  //     gas: 5000000
  //   }
  // },
  //Ganache CLI
  //     networks: {
  //       development: {
  //         host: "127.0.0.1",
  //         port: 8545,
  //         network_id: "*", // Match any network id
  //       },
  //     },
  //Ganache GUI
  networks: {
        development: {
          host: "127.0.0.1",
          port: 7545,
          network_id: "*", // Match any network id
        },
      },
    // compilers: {
    // solc: {
    //   version: "0.8.0"
    // }
  // }
  compilers: {
    solc: {
      version: "0.8.19",
      settings: {
        optimizer: {
          enabled: true, // Default: false
          runs: 200      // Default: 200
        },
      }
    }
  }
};
