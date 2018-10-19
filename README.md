# mind-breed

MindBreed is a [CryptoKitties](https://www.cryptokitties.co/) powered [Brainfuck interpreter](https://en.wikipedia.org/wiki/Brainfuck).

## Introduction

Brainfuck is an esoteric programming langauge with eight instructions (`>`, `<`, `+`, `-`, `.`, `,`, `[`, `]`). Using these eight instructions, you can run programs that produce output.

MindBreed is a special type of Brainfuck interpreter that doesn't understand text input - only the fur patterns on CryptoKitties. Instead of simply typing out instructions, you must sacrifice an innocent kitty to the EVM for each added instruction.

Here are the equivalent instructions:

| Fur Pattern | Instruction |
| ----------- | ----------- |
| savannah    | +           |
| selkirk     | ,           |
| birman      | -           |
| koladiviya  | .           |
| bobtail     | <           |
| pixiebob    | >           |
| cymric      | [           |
| chartreux   | ]           |

You can only add instructions onto the end of your program. You can pop instructions off the end, but you don't get your kitty back. Every MindBreed contract comes with a bounty - if you execute the right program, you get that bounty. Happy sacrificing.
