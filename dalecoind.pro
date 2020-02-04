TEMPLATE = app
TARGET = dalecoind
VERSION = 3.0.0

count(USE_WALLET, 0) {
    USE_WALLET=1
}
contains(USE_WALLET, 1) {
    message(Building with WALLET support)
    CONFIG += wallet
}

count(USE_TESTNET, 1) {
    contains(USE_TESTNET, 1) {
        message(Building with TESTNET enabled)
        DEFINES += USE_TESTNET
    }
}

count(USE_FAUCET, 1) {
    contains(USE_FAUCET, 1) {
        message(Building with FAUCET support)
        CONFIG += faucet
    }
}

count(USE_EXCHANGE, 1) {
    contains(USE_EXCHANGE, 1) {
        message(Building with EXCHANGE support)
        CONFIG += exchange
    }
}

exists(dalecoind-local.pri) {
    include(dalecoind-local.pri)
}

CONFIG -= qt
INCLUDEPATH += build

# mac builds
include(dalecoin-mac.pri)

INCLUDEPATH += src src/json src/qt $$PWD
DEFINES += BOOST_THREAD_USE_LIB
DEFINES += BOOST_SPIRIT_THREADSAFE
DEFINES += BOOST_NO_CXX11_SCOPED_ENUMS
CONFIG += console
CONFIG -= app_bundle
CONFIG += no_include_pwd
CONFIG += thread
CONFIG += c++11

greaterThan(QT_MAJOR_VERSION, 4) {
    DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0
}

# for boost 1.37, add -mt to the boost libraries
# use: qmake BOOST_LIB_SUFFIX=-mt
# for boost thread win32 with _win32 sufix
# use: BOOST_THREAD_LIB_SUFFIX=_win32-...
# or when linking against a specific BerkelyDB version: BDB_LIB_SUFFIX=-4.8

# Dependency library locations can be customized with:
#    BOOST_INCLUDE_PATH, BOOST_LIB_PATH, BDB_INCLUDE_PATH,
#    BDB_LIB_PATH, OPENSSL_INCLUDE_PATH and OPENSSL_LIB_PATH respectively

OBJECTS_DIR = build
MOC_DIR = build
UI_DIR = build

!win32 {
	# for extra security against potential buffer overflows: enable GCCs Stack Smashing Protection
	QMAKE_CXXFLAGS *= -fstack-protector-all --param ssp-buffer-size=1
	QMAKE_LFLAGS *= -fstack-protector-all --param ssp-buffer-size=1
	# We need to exclude this for Windows cross compile with MinGW 4.2.x, as it will result in a non-working executable!
	# This can be enabled for Windows, when we switch to MinGW >= 4.4.x.
}
# for extra security on Windows: enable ASLR and DEP via GCC linker flags
#win32:QMAKE_LFLAGS *= -Wl,--dynamicbase -Wl,--nxcompat
#win32:QMAKE_LFLAGS += -static-libgcc -static-libstdc++

# use: qmake "USE_UPNP=1" ( enabled by default; default)
#  or: qmake "USE_UPNP=0" (disabled by default)
#  or: qmake "USE_UPNP=-" (not supported)
# miniupnpc (http://miniupnp.free.fr/files/) must be installed for support
contains(USE_UPNP, -) {
    message(Building without UPNP support)
} else {
    message(Building with UPNP support)
    count(USE_UPNP, 0) {
        USE_UPNP=1
    }
    DEFINES += USE_UPNP=$$USE_UPNP MINIUPNP_STATICLIB STATICLIB
    INCLUDEPATH += $$MINIUPNPC_INCLUDE_PATH
    LIBS += $$join(MINIUPNPC_LIB_PATH,,-L,) -lminiupnpc
    win32:LIBS += -liphlpapi
}

INCLUDEPATH += src/leveldb/include src/leveldb/helpers
LIBS += $$PWD/src/leveldb/out-static/libleveldb.a $$PWD/src/leveldb/out-static/libmemenv.a
HEADERS += src/txdb-leveldb.h
SOURCES += src/txdb-leveldb.cpp
!win32 {
    # we use QMAKE_CXXFLAGS_RELEASE even without RELEASE=1 because we use RELEASE to indicate linking preferences not -O preferences
    macx:LEVELDB_CXXFLAGS=-mmacosx-version-min=10.9
    genleveldb.commands = cd $$PWD/src/leveldb && CC=$$QMAKE_CC CXX=$$QMAKE_CXX $(MAKE) OPT=\"$$QMAKE_CXXFLAGS $$LEVELDB_CXXFLAGS $$QMAKE_CXXFLAGS_RELEASE\" out-static/libleveldb.a out-static/libmemenv.a
} else {
    # make an educated guess about what the ranlib command is called
    isEmpty(QMAKE_RANLIB) {
    #	QMAKE_RANLIB = $$replace(QMAKE_STRIP, strip, ranlib)
        QMAKE_RANLIB = echo
    }
    LIBS += -lshlwapi
    genleveldb.commands = cd $$PWD/src/leveldb && CC=$$QMAKE_CC CXX=$$QMAKE_CXX TARGET_OS=OS_WINDOWS_CROSSCOMPILE $(MAKE) OPT=\"$$QMAKE_CXXFLAGS $$QMAKE_CXXFLAGS_RELEASE\" out-static/libleveldb.a out-static/libmemenv.a && $$QMAKE_RANLIB $$PWD/src/leveldb/out-static/libleveldb.a && $$QMAKE_RANLIB $$PWD/src/leveldb/out-static/libmemenv.a
}
genleveldb.target = $$PWD/src/leveldb/out-static/libleveldb.a
genleveldb.depends = FORCE
PRE_TARGETDEPS += $$PWD/src/leveldb/out-static/libleveldb.a
QMAKE_EXTRA_TARGETS += genleveldb
# Gross ugly hack that depends on qmake internals, unfortunately there is no other way to do it.
QMAKE_CLEAN += $$PWD/src/leveldb/out-static/libleveldb.a; cd $$PWD/src/leveldb ; $(MAKE) clean

# regenerate src/build.h
!windows|contains(USE_BUILD_INFO, 1) {
    genbuild.depends = FORCE
    genbuild.commands = cd $$PWD; /bin/sh share/genbuild.sh $$OUT_PWD/build/build.h
    genbuild.target = $$OUT_PWD/build/build.h
    PRE_TARGETDEPS += $$OUT_PWD/build/build.h
    QMAKE_EXTRA_TARGETS += genbuild
    DEFINES += HAVE_BUILD_INFO
}

contains(USE_O3, 1) {
    message(Building O3 optimization flag)
    QMAKE_CXXFLAGS_RELEASE -= -O2
    QMAKE_CFLAGS_RELEASE -= -O2
    QMAKE_CXXFLAGS += -O3
    QMAKE_CFLAGS += -O3
}

*-g++-32 {
    message("32 platform, adding -msse2 flag")

    QMAKE_CXXFLAGS += -msse2
    QMAKE_CFLAGS += -msse2
}

QMAKE_CXXFLAGS_WARN_ON = -fdiagnostics-show-option -Wall -Wextra -Wno-ignored-qualifiers -Wformat -Wformat-security -Wno-unused-parameter -Wstack-protector

#json lib
include(src/json/json.pri)

#core
include(src/core.pri)

SOURCES += \
	src/bitcoind.cpp \

CODECFORTR = UTF-8

# platform specific defaults, if not overridden on command line
isEmpty(BOOST_LIB_SUFFIX) {
    macx:BOOST_LIB_SUFFIX = -mt
    windows:BOOST_LIB_SUFFIX = -mt
}

isEmpty(BOOST_THREAD_LIB_SUFFIX) {
    win32:BOOST_THREAD_LIB_SUFFIX = $$BOOST_LIB_SUFFIX
    else:BOOST_THREAD_LIB_SUFFIX = $$BOOST_LIB_SUFFIX
}

windows:DEFINES += WIN32
windows:RC_FILE = src/qt/res/bitcoin-qt.rc

windows:!contains(MINGW_THREAD_BUGFIX, 0) {
    # At least qmake's win32-g++-cross profile is missing the -lmingwthrd
    # thread-safety flag. GCC has -mthreads to enable this, but it doesn't
    # work with static linking. -lmingwthrd must come BEFORE -lmingw, so
    # it is prepended to QMAKE_LIBS_QT_ENTRY.
    # It can be turned off with MINGW_THREAD_BUGFIX=0, just in case it causes
    # any problems on some untested qmake profile now or in the future.
    DEFINES += _MT BOOST_THREAD_PROVIDES_GENERIC_SHARED_MUTEX_ON_WIN
    QMAKE_LIBS_QT_ENTRY = -lmingwthrd $$QMAKE_LIBS_QT_ENTRY
}

# Set libraries and includes at end, to use platform-defined defaults if not overridden
INCLUDEPATH += $$BDB_INCLUDE_PATH 
INCLUDEPATH += $$BOOST_INCLUDE_PATH 
INCLUDEPATH += $$OPENSSL_INCLUDE_PATH

LIBS += $$join(BDB_LIB_PATH,,-L,) 
LIBS += $$join(BOOST_LIB_PATH,,-L,) 
LIBS += $$join(OPENSSL_LIB_PATH,,-L,)
LIBS += -lssl -lcrypto 
LIBS += -ldb$$BDB_LIB_SUFFIX 
LIBS += -ldb_cxx$$BDB_LIB_SUFFIX
LIBS += -lz

# -lgdi32 has to happen after -lcrypto (see  #681)
windows:LIBS += -lws2_32 -lshlwapi -lmswsock -lole32 -loleaut32 -luuid -lgdi32

LIBS += -lboost_system$$BOOST_LIB_SUFFIX 
LIBS += -lboost_filesystem$$BOOST_LIB_SUFFIX 
LIBS += -lboost_program_options$$BOOST_LIB_SUFFIX 
LIBS += -lboost_thread$$BOOST_THREAD_LIB_SUFFIX
LIBS += -lboost_chrono$$BOOST_LIB_SUFFIX

DISTFILES += \
    src/makefile.osx \
    src/makefile.unix \
    .travis.yml \
    .appveyor.yml

