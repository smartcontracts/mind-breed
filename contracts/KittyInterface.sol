pragma solidity ^0.4.0;

interface KittyInterface {
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external;

    function getKitty(uint256 _id) external view returns (
        bool isGestating,
        bool isReady,
        uint256 cooldownIndex,
        uint256 nextActionAt,
        uint256 siringWithId,
        uint256 birthTime,
        uint256 matronId,
        uint256 sireId,
        uint256 generation,
        uint256 genes
    );
}
