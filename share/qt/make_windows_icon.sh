#!/bin/bash
# create multiresolution windows icon
ICON_DST=../../src/qt/res/icons/wallet.ico

convert ../../src/qt/res/icons/DaleCoin-Wallet-Icon-16.png ../../src/qt/res/icons/DaleCoin-Wallet-Icon-32.png ../../src/qt/res/icons/DaleCoin-Wallet-Icon-48.png ${ICON_DST}
