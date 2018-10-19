/**
 * This file is part of the 1st Solidity Gas Golfing Contest.
 *
 * This work is licensed under Creative Commons Attribution ShareAlike 3.0.
 * https://creativecommons.org/licenses/by-sa/3.0/
 *
 * Author: Greg Hysen (hyszeth.eth)
 * Date: June 2018
 * Description: Executes a Brainfuck program.
 *              The program is first encoded into a data structure
 *              that is optimized for execution on the EVM.
 *              This structure is then passed to an interpreter for execution.
 *
 */

pragma solidity 0.4.24;

library Brainfuck {

    // Constants used throughout the algorithm
    uint constant BITSHIFT = 0x100000000000000000000000000000000000000000000000000000000000000;
    bytes32 constant INS_MASK = 0xff00000000000000000000000000000000000000000000000000000000000000;
    bytes32 constant VAL_MASK = 0x00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint constant PLUS = 0x2B;
    uint constant COMMA = 0x2C;
    uint constant MINUS = 0x2D;
    uint constant PERIOD = 0x2E;
    uint constant L_SHIFT = 0x3C;
    uint constant R_SHIFT = 0x3E;
    uint constant L_BRACKET = 0x5B;
    uint constant R_BRACKET = 0x5D;
    uint constant PLUS_SHIFTED = 0x2B00000000000000000000000000000000000000000000000000000000000000;
    uint constant COMMA_SHIFTED = 0x2C00000000000000000000000000000000000000000000000000000000000000;
    uint constant MINUS_SHIFTED = 0x2D00000000000000000000000000000000000000000000000000000000000000;
    uint constant PERIOD_SHIFTED = 0x2E00000000000000000000000000000000000000000000000000000000000000;
    uint constant L_SHIFT_SHIFTED = 0x3C00000000000000000000000000000000000000000000000000000000000000;
    uint constant R_SHIFT_SHIFTED = 0x3E00000000000000000000000000000000000000000000000000000000000000;
    uint constant L_BRACKET_SHIFTED = 0x5B00000000000000000000000000000000000000000000000000000000000000;
    uint constant R_BRACKET_SHIFTED = 0x5D00000000000000000000000000000000000000000000000000000000000000;

    /**
     * @dev Executes a BrainFuck program, as described at https://en.wikipedia.org/wiki/Brainfuck.
     *
     * Memory cells, input, and output values are all expected to be 8 bit
     * integers. Incrementing past 255 should overflow to 0, and decrementing
     * below 0 should overflow to 255.
     *
     * Programs and input streams may be of any length. The memory tape starts
     * at cell 0, and will never be moved below 0 or above 1023. No program will
     * output more than 1024 values.
     *
     * @param program The BrainFuck program.
     * @param input The program's input stream.
     * @return The program's output stream. Should be exactly the length of the
     *          number of outputs produced by the program.
     */
    function execute(bytes program, bytes input)
        internal
        pure
        returns(bytes)
    {
        // `data` stores the program output in the first 1024 bytes and
        //        the "memeory tape" in latter 1024 bytes.
        uint[2048] memory data;

        // Begin by analyzing the program. This returns
        // a runtime-optimized data structure.
        uint programLength = program.length;
        (
            bool hasOutput,
            bytes32[] memory optimizedProgram,
	          uint optimizedProgramLength
        ) = optimizeProgram(program, data, program.length);
        if(!hasOutput) return;

        // Run the optimized program.
        // `programLength` holds the output length.
        programLength = runOptimizedProgram(
            optimizedProgram,
            input,
            data,
            0,          // output pointer (into `data`)
            1024,       // memory pointer (into `data`)
            uint(-1),   // input pointer (into `input`)
            0,          // program pointer (into `optimizedProgram`)
            optimizedProgramLength
        );

        // Copy program output from `data` to a separate array.
        bytes memory output = new bytes(programLength);
        for(uint i = 0; i != programLength; ++i) {
            output[i] = byte(data[i]);
        }
        return output;
    }

    /**
     * @dev Optimizes a Brainfuck program for execution on the EVM.
     *
     *    The input program is converted to the following data structure:
     *    [255 .. value .. 8][7 .. instruction .. 0]
     *    [255 .. value .. 8][7 .. instruction .. 0]
     *                      ....
     *    Where:
     *      `instruction` is a brainfuck instruction and occupies the rightmost byte.
     *      `value` is the argument to `instruction` and occupies the leftmost 31 bytes.
     *
     *    When combined [`value`|`instruction`] occupies 1 word of memory (32 bytes).
     *    The entire program is then stored in a bytes32[].
     *
     *    For instructions +,-.<>  -- `value` is the number of times `instruction`
     *                                 should be executed.
     *    For instructions [ and ] -- `value` is the jump index.
     *
     * @param program The (unoptimized) BrainFuck program.
     * @param data The data array used to store the program's output and memory.
     * @param programLength Length of the (unoptimized) Brainfuck program.
     * @return hasOutput True if the program would produce output. False otherwise.
     * @return optimizedProgram Program encoded into the data structure described above.
     * @return optimizedPPtr Optimized program length.
     */
    function optimizeProgram(
        bytes program,
        uint[2048] memory data,
        uint programLength
    )
        internal
        pure
        returns (
            bool hasOutput,
            bytes32[] memory optimizedProgram,
            uint optimizedPPtr
        )
    {
        // A lookup table for valid characters.
        bool[256] memory lookup;
        lookup[PLUS] = true;
        lookup[COMMA] = true;
        lookup[MINUS] = true;
        lookup[PERIOD] = true;
        lookup[L_SHIFT] = true;
        lookup[R_SHIFT] = true;
        lookup[L_BRACKET] = true;
        lookup[R_BRACKET] = true;
        // Current instruction.
        uint ins;
        // Current count of consecutive equivalent instructions.
        uint count;
        // Branch balance. Used for tracking jump locations.
        uint balance;
        // optimizedProgram
        optimizedProgram = new bytes32[](programLength);
        // Current index into `program`
        uint i;
        // Current jump location
        uint jumpLocation;

        // Run algorithm, performing the following operations:
        // 1. Check if there's output.
        // 2. Combine consecutive equivalent instructions.
        // 3. Filter out NOP characters.
        // 4. Construct an inline jumptable for `[` and `]`
        do {
            ins = uint(program[i++]);
            if(ins == L_BRACKET) {
                data[balance++] = optimizedPPtr;
                optimizedProgram[optimizedPPtr++] = bytes32(uint(ins) * BITSHIFT);
            } else if(ins == R_BRACKET) {
                optimizedProgram[(jumpLocation = data[--balance])] |= bytes32(optimizedPPtr+1); // next instruction after ]
                optimizedProgram[optimizedPPtr++] = bytes32(ins * BITSHIFT | (jumpLocation+1));
            } else {
                count = 1;
                uint tmp;
                for(; i != programLength; i++) {
                    if(ins == (tmp=uint(program[i]))) {
                        count++;
                    } else if(lookup[uint(tmp)]) {
                        break;
                    }
                }
                if(lookup[uint(ins)]) {
                    optimizedProgram[optimizedPPtr++] = bytes32(ins * BITSHIFT | count);
                    if(ins == PERIOD) hasOutput = true;
                }
            }
        } while(i != programLength);
        return (hasOutput, optimizedProgram, optimizedPPtr);
    }

    /**
     * @dev Runs an optimized Brainfuck program.
     * @param program The (optimized) BrainFuck program.
     * @param input The input to the Brainfuck program.
     * @param data The data array used to store the program's output and memory.
     * @param oPtr Output pointer.
     * @param mPtr Memory pointer.
     * @param iPtr Input pointer.
     * @param pPtr Program pointer.
     * @param programLength Length of the (optimized) Brainfuck program.
     * @return Length of output.
     */
    function runOptimizedProgram(
        bytes32[] memory program,
        bytes memory input,
        uint[2048] memory data,
        uint oPtr,
        uint mPtr,
        uint iPtr,
        uint pPtr,
        uint programLength
    )
        internal
        pure
        returns (uint)
    {
        // Data cache. Minimizes the number of writes to `data`.
        uint dCache;

        // Run program
        while(pPtr != programLength) {
            // Read next line and parse out [instruction, value] pair.
            bytes32 line = program[pPtr++];
            uint ins = uint(line & INS_MASK);
            uint val = uint(line & VAL_MASK);

            // Execute instruction
            if(ins == R_BRACKET_SHIFTED) {
                if(dCache != 0) pPtr = val;
            } else if(ins == PLUS_SHIFTED) {
                dCache = (dCache + val) & 255;
            } else if(ins == MINUS_SHIFTED) {
                dCache = (dCache - val) & 255;
            } else if(ins == R_SHIFT_SHIFTED) {
                data[mPtr] = dCache;
                dCache = data[(mPtr += val)];
            } else if(ins == L_SHIFT_SHIFTED) {
                data[mPtr] = dCache;
                dCache = data[(mPtr -= val)];
            } else if(ins == COMMA_SHIFTED) {
                dCache = data[mPtr] = uint8(input[(iPtr += val)]);
            } else if(ins == PERIOD_SHIFTED) {
                while(val-- != 0) data[oPtr++] = dCache;
            } else if(ins == L_BRACKET_SHIFTED) {
                if(dCache == 0) pPtr = val;
            }
        }

        return oPtr;
    }
}
