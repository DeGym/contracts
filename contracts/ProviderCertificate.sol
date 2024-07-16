// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IStakeContract {
    function getStake(address user) external view returns (uint256);
}

contract ProviderCertificate is ERC721URIStorage, Ownable {
    struct Certificate {
        uint256 tier;
        bool isValid;
    }

    mapping(uint256 => Certificate) public certificates;
    IStakeContract public stakeContract;
    uint256 public minimumStake;
    uint256 public nextTokenId;

    constructor(
        address stakeContractAddress,
        uint256 minStake
    ) ERC721("Provider Certificate", "PC") {
        stakeContract = IStakeContract(stakeContractAddress);
        minimumStake = minStake;
    }

    function issueCertificate(address to, uint256 tier) public onlyOwner {
        require(
            stakeContract.getStake(to) >= minimumStake,
            "Insufficient stake to issue certificate"
        );
        uint256 tokenId = nextTokenId;
        _mint(to, tokenId);
        _setTokenURI(tokenId, "ipfs://Qm..."); // Example IPFS URI
        certificates[tokenId] = Certificate(tier, true);
        nextTokenId++;
    }

    function validateCertificate(uint256 tokenId) public view returns (bool) {
        require(_exists(tokenId), "Certificate does not exist");
        return
            certificates[tokenId].isValid &&
            stakeContract.getStake(ownerOf(tokenId)) >= minimumStake;
    }

    function getTier(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "Certificate does not exist");
        return certificates[tokenId].tier;
    }

    function revokeCertificate(uint256 tokenId) public onlyOwner {
        require(_exists(tokenId), "Certificate does not exist");
        certificates[tokenId].isValid = false;
    }
}
