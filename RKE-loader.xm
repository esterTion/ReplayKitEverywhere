#include <dlfcn.h>

%ctor {

NSString *exePath = [[NSBundle mainBundle] executablePath];
if ([exePath containsString: @"/Application/"] && [exePath containsString: @".app/"]) {
	dlopen("/Library/MobileSubstrate/DynamicLibraries/ReplayKitEverywhere.dylib", RTLD_NOW);
}


}