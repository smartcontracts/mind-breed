pragma solidity ^0.4.0;

import "./BrainFuck.sol";
import "./KittyInterface.sol";


/**
 * @title A CryptoKitties powered Brainfuck interpreter.
 * @author kfichter
 */
contract MindBreed {
    /*
     * Storage
     */

    KittyInterface kittyContract = KittyInterface(0x06012c8cf97BEaD5deAe237070F9587f8E7A266d);
    mapping (address => bytes1[]) programs;

    /*
     * Events
     */

    event BountyClaimed(
        address winner
    );

    function () public payable {}

    /**
     * @dev Adds an item to the stack by sacrificing a kitty.
     * @param _kittyId Kitty to sacrifice.
     */
    function push(uint256 _kittyId) public {
        kittyContract.transferFrom(msg.sender, address(this), _kittyId);
        programs[msg.sender].push(translateKitty(_kittyId));
    }

    /**
     * @dev Pops an item from the stack.
     */
    function pop() public {
        bytes1[] storage program = programs[msg.sender];
        delete program[program.length - 1];
        program.length--;
    }

    /**
     * @dev Allows a user to claim the bounty by executing the right program.
     */
    function claimBounty() public {
        bytes memory input;
        bytes32 result = keccak256(BrainFuck.execute(getProgram(msg.sender), input));
        bytes32 target = keccak256(abi.encodePacked(bytes2(0x6869))); // hey hey heyyy
        require(result == target, "Invalid result.");

        msg.sender.transfer(address(this).balance);
        emit BountyClaimed(msg.sender);
    }

    /**
     * @dev Converts a kitty to the correct Brainfuck instruction.
     * @param _kittyId Kitty to convert.
     * @return Brainfuck instruction, represented as hex.
     */
    function translateKitty(uint256 _kittyId) internal view returns (bytes1) {
        // Lookup table 
        bytes1[256] memory lookup;
        lookup[0] = 0x2B; // PLUS
        lookup[1] = 0x2C; // COMMA
        lookup[3] = 0x2D; // MINUS
        lookup[4] = 0x2E; // PERIOD
        lookup[5] = 0x3C; // L_SHIFT
        lookup[7] = 0x3E; // R_SHIFT
        lookup[9] = 0x5B; // L_BRACKET
        lookup[10] = 0x5D; // R_BRACKET

        uint256 genes;
        (, , , , , , , , , genes) = kittyContract.getKitty(_kittyId);
        bytes1 instruction = lookup[genes & 0x0F];
        require(instruction != 0x00, "Invalid instruction.");
        return instruction;
    }

    /**
     * @dev Converts a user's stack into a program to be executed.
     * @param _user Address of the user to access.
     * @return The user's converted program.
     */
    function getProgram(address _user) internal view returns (bytes) {
        uint length = programs[_user].length;
        bytes memory program = new bytes(length);
        for (uint i = 0; i < length; i++) {
            program[i] = programs[_user][i];
        }
        return program;
    }
}
