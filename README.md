# PW
PW is a password manager for Unix-based systems that uses asymmetric keys for encryption. It depends on `openssl`, `tar`, and a `dash`-compatible shell (such as `ash` or `bash`).

## Install
To install PW, run `install pw.sh [your-bin-dir]`.

## Configuration
PW can be configured by editing the following parameters in the source code:

+ `PASSGENLEN`: The length of generated passwords.
+ `MAXPASSLEN`: The maximum length of user-entered passwords.
+ `PROGNAME`: The name of the program.
+ `BASEDIR`: The base directory for the program.
+ `PWDIR`: The directory for program files.

## Usage
To use PW, run one of the following commands:
+ `pw get NAME`: Decrypt and display an entry named NAME.
+ `pw set NAME`: Create or modify an entry named NAME.
+ `pw del NAME`: Delete an entry named NAME.
+ `pw gen NAME`: Generate and save a random password in an entry named NAME.
+ `pw list`: List all saved entries.
+ `pw export FILENAME?`: Export the entire vault to a tar.gz file, including keys and entries.

## Encryption
PW uses a 4096-bit RSA key pair to encrypt data, with the private key encrypted with AES-256 and protected with a user-defined passphrase. The keys and saved passwords can be exported with `pw export`. 

## Compatibility
PW is compatible with most modern Unix-based systems.
