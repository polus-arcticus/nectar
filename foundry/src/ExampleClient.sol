// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IHiveJobManager.sol";
import "./interfaces/IHiveJobClient.sol";
import "forge-std/console.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
struct JobArgs {
    string message;
}

contract ExampleClient is IHiveJobClient {
    address private jobManagerAddress;
    IHiveJobManager private jobManagerContract;

    mapping(uint256 => string) private jobResults;
    mapping(Currency => uint256) public jobPrices;
    JobArgs public jobArgs;
    event JobCreated(uint256 id, string message);

    event JobCompleted(uint256 id, string dealId, string dataId);

    constructor(address _jobManagerAddress) {
        console.log("inside example client constructor");
        setJobManagerAddress(_jobManagerAddress);
    }

    modifier onlyJobManager() {
        require(msg.sender == jobManagerAddress, "Only job manager");
        _;
    }

    function setJobManagerAddress(address _jobManagerAddress) public {
        require(_jobManagerAddress != address(0), "Job manager address");
        jobManagerAddress = _jobManagerAddress;
        jobManagerContract = IHiveJobManager(jobManagerAddress);
    }

    function setJobArgs(JobArgs memory _jobArgs) public onlyJobManager {
        jobArgs = _jobArgs;
    }

    function setJobPrice(
        Currency _currency,
        uint256 _price
    ) public onlyJobManager {
        jobPrices[_currency] = _price;
    }

    function getJobResult(uint256 _jobID) public view returns (string memory) {
        return jobResults[_jobID];
    }

    function runCowsay(string memory message) public {
        string[] memory inputs = new string[](1);
        inputs[0] = string(abi.encodePacked("Message=", message));
        uint256 id = jobManagerContract.runJob(
            "cowsay:v0.0.1",
            inputs,
            msg.sender
        );

        emit JobCreated(id, message);
    }

    function submitResults(
        uint256 id,
        string memory dealId,
        string memory dataId
    ) public override {
        jobResults[id] = dataId;
        emit JobCompleted(id, dealId, dataId);
    }
}
