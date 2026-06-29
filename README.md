# Super Smash Bros. Melee Recompilation Experiment

An experiment, based off of [MansionRecomp](https://github.com/ExpansionPak/MansionRecomp)

Everything is setup and done through this repository, so just clone the repo, have the tools installed, and a legally aquired Super Smash Bros. Melee Iso file. All building and running can be done through the Makefile.

## Setup

Create a folder called iso and place the melee ISO file in there, and rename the ISO file to ssbm.iso.

To get all the tools necessary to install and run code, do this

```bash
make setup
```

## Running

Just run

```bash
make build
```

It will

- Extract the main.dol file from the ISO file using DolRecomp
- Generate the code using DolRecomp
- The rest is still not implemented

## Notes

- Currently waiting for permission to get access too, https://github.com/ExpansionPak/GXRecomp.git and https://github.com/ExpansionPak/ModernGekko.git
- This will change as MansionRecomp switches to using Dolphin's video backend logic
- Using the make help from gf180 template
- Will update src and CMakeLists.txt when Mansion reachs its next stable form of building
