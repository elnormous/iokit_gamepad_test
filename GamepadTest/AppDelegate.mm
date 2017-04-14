//
//  AppDelegate.m
//  GamepadTest
//
//  Created by Elviss Strazdins on 25/03/2017.
//  Copyright © 2017 Elviss Strazdins. All rights reserved.
//

#include <iostream>
#include <memory>
#include <vector>
#include <map>
#import <IOKit/hid/IOHIDManager.h>
#import "AppDelegate.h"

@implementation AppDelegate

IOHIDManagerRef hidManager;

static void deviceInput(void* ctx, IOReturn inResult, void* inSender, IOHIDValueRef value);

enum UsageID
{
    NONE,

    DPAD_LEFT_USAGE_ID,
	DPAD_RIGHT_USAGE_ID,
	DPAD_DOWN_USAGE_ID,
	DPAD_UP_USAGE_ID,

    START_BUTTON_USAGE_ID,
    BACK_BUTTON_USAGE_ID,
	PAUSE_BUTTON_USAGE_ID,

	A_BUTTON_USAGE_ID,
	B_BUTTON_USAGE_ID,
	X_BUTTON_USAGE_ID,
	Y_BUTTON_USAGE_ID,
	LEFT_SHOULDER_USAGE_ID,
	RIGHT_SHOULDER_USAGE_ID,
    LEFT_TRIGGER_USAGE_ID,
    RIGHT_TRIGGER_USAGE_ID,
    LEFT_THUMBSTICK_USAGE_ID,
    RIGHT_THUMBSTICK_USAGE_ID,
};

static std::string usageToString(UsageID usageId)
{
    switch (usageId)
    {
        case DPAD_LEFT_USAGE_ID: return "D-pad left";
        case DPAD_RIGHT_USAGE_ID: return "D-pad right";
        case DPAD_DOWN_USAGE_ID: return "D-pad down";
        case DPAD_UP_USAGE_ID: return "D-pad up";

        case START_BUTTON_USAGE_ID: return "Start";
        case BACK_BUTTON_USAGE_ID: return "Back";
        case PAUSE_BUTTON_USAGE_ID: return "Pause";

        case A_BUTTON_USAGE_ID: return "A";
        case B_BUTTON_USAGE_ID: return "B";
        case X_BUTTON_USAGE_ID: return "X";
        case Y_BUTTON_USAGE_ID: return "Y";
        case LEFT_SHOULDER_USAGE_ID: return "Left shoulder";
        case RIGHT_SHOULDER_USAGE_ID: return "Right shoulder";
        case LEFT_TRIGGER_USAGE_ID: return "Left trigger";
        case RIGHT_TRIGGER_USAGE_ID: return "Right trigger";
        case LEFT_THUMBSTICK_USAGE_ID: return "Left thumbstick";
        case RIGHT_THUMBSTICK_USAGE_ID: return "Right thumbstick";
        default:
            return "Unknown";
    }
}

class GamepadElement
{
public:
    enum class Type
    {
        NONE,
        BUTTON,
        HAT,
        ANALOG
    };

    GamepadElement(IOHIDElementRef aElement):
        element(aElement)
    {
        IOHIDElementType elementType = IOHIDElementGetType(element);
        usage = IOHIDElementGetUsage(element);
        uint32_t usagePage = IOHIDElementGetUsagePage(element);

        min = IOHIDElementGetPhysicalMin(element);
        max = IOHIDElementGetPhysicalMax(element);

        if (elementType == kIOHIDElementTypeInput_Misc ||
            elementType == kIOHIDElementTypeInput_Axis ||
            elementType == kIOHIDElementTypeInput_Button)
        {
            if (max - min == 1 ||
                usagePage == kHIDPage_Button ||
                elementType == kIOHIDElementTypeInput_Button)
            {
                type = Type::BUTTON;
            }
            else if (usage == kHIDUsage_GD_Hatswitch)
            {
                type = Type::HAT;
            }
            else if (usage >= kHIDUsage_GD_X && usage <= kHIDUsage_GD_Rz)
            {
                type = Type::ANALOG;
            }
        }
    }

    Type getType() const { return type; }
    CFIndex getMin() const { return min; }
    CFIndex getMax() const { return max; }
    uint32_t getUsage() const { return usage; }

    float normalizeValue(CFIndex value) const
    {
        return static_cast<float>(value - min) / (max - min);
    }

protected:
    IOHIDElementRef element = Nil;
    Type type = Type::NONE;
    CFIndex min = 0;
    CFIndex max = 0;
    uint32_t usage;
};

class Gamepad
{
public:
    Gamepad(IOHIDDeviceRef aDevice):
        device(aDevice)
    {
        NSString* productKey = (NSString*)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        if (productKey)
        {
            name = [productKey cStringUsingEncoding:NSUTF8StringEncoding];
        }

        NSNumber* currentId = (NSNumber*)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDUniqueIDKey));
        if (currentId)
        {
            uniqueId = [currentId integerValue];
        }

        NSNumber* vendor = (NSNumber*)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
        if (vendor)
        {
            vendorId = [vendor integerValue];
        }

        NSNumber* deviceId = (NSNumber*)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDPhysicalDeviceUniqueIDKey));
        if (deviceId)
        {
            uniqueDeviceId = [deviceId integerValue];
        }

        NSNumber* product = (NSNumber*)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
        if (product)
        {
            productId = [product integerValue];
        }

        std::fill(std::begin(usageMap), std::end(usageMap), NONE);

        if (vendorId == 0x054C && productId == 0x0268) // Playstation 3 controller
        {
            usageMap[1] = BACK_BUTTON_USAGE_ID; // Select
            usageMap[2] = LEFT_THUMBSTICK_USAGE_ID; // L3
            usageMap[3] = RIGHT_THUMBSTICK_USAGE_ID; // R3
            usageMap[4] = START_BUTTON_USAGE_ID; // Start
            usageMap[5] = DPAD_UP_USAGE_ID;
            usageMap[6] = DPAD_RIGHT_USAGE_ID;
            usageMap[7] = DPAD_DOWN_USAGE_ID;
            usageMap[8] = DPAD_LEFT_USAGE_ID;
            usageMap[9] = LEFT_TRIGGER_USAGE_ID; // L2
            usageMap[10] = RIGHT_TRIGGER_USAGE_ID; // R2
            usageMap[11] = LEFT_SHOULDER_USAGE_ID; // L1
            usageMap[12] = RIGHT_SHOULDER_USAGE_ID; // R1
            usageMap[13] = Y_BUTTON_USAGE_ID; // Triangle
            usageMap[14] = B_BUTTON_USAGE_ID; // Circle
            usageMap[15] = A_BUTTON_USAGE_ID; // Cross
            usageMap[16] = X_BUTTON_USAGE_ID; // Square

            leftAnalogXMap = kHIDUsage_GD_X;
            leftAnalogYMap = kHIDUsage_GD_Y;
            leftTriggerAnalogMap = kHIDUsage_GD_Rx;
            rightAnalogXMap = kHIDUsage_GD_Z;
            rightAnalogYMap = kHIDUsage_GD_Rz;
            rightTriggerAnalogMap = kHIDUsage_GD_Ry;
        }
        else if (vendorId == 0x054C && productId == 0x05C4) // Playstation 4 controller
        {
            usageMap[1] = X_BUTTON_USAGE_ID; // Square
            usageMap[2] = A_BUTTON_USAGE_ID; // Cross
            usageMap[3] = B_BUTTON_USAGE_ID; // Circle
            usageMap[4] = Y_BUTTON_USAGE_ID; // Triangle
            usageMap[5] = LEFT_SHOULDER_USAGE_ID; // L1
            usageMap[6] = RIGHT_SHOULDER_USAGE_ID; // R1
            usageMap[7] = LEFT_TRIGGER_USAGE_ID; // L2
            usageMap[8] = RIGHT_TRIGGER_USAGE_ID; // R2
            usageMap[9] = BACK_BUTTON_USAGE_ID; // Share
            usageMap[10] = START_BUTTON_USAGE_ID; // Options
            usageMap[11] = LEFT_THUMBSTICK_USAGE_ID; // L3
            usageMap[12] = RIGHT_THUMBSTICK_USAGE_ID; // R3

            leftAnalogXMap = kHIDUsage_GD_X;
            leftAnalogYMap = kHIDUsage_GD_Y;
            leftTriggerAnalogMap = kHIDUsage_GD_Rx;
            rightAnalogXMap = kHIDUsage_GD_Z;
            rightAnalogYMap = kHIDUsage_GD_Rz;
            rightTriggerAnalogMap = kHIDUsage_GD_Ry;
        }
        else if (vendorId == 0x045E && productId == 0x02d1) // Xbox One controller
        {
            usageMap[1] = A_BUTTON_USAGE_ID;
            usageMap[2] = B_BUTTON_USAGE_ID;
            usageMap[3] = X_BUTTON_USAGE_ID;
            usageMap[4] = Y_BUTTON_USAGE_ID;
            usageMap[5] = LEFT_SHOULDER_USAGE_ID;
            usageMap[6] = RIGHT_SHOULDER_USAGE_ID;
            usageMap[7] = LEFT_THUMBSTICK_USAGE_ID;
            usageMap[8] = RIGHT_THUMBSTICK_USAGE_ID;
            usageMap[9] = BACK_BUTTON_USAGE_ID; // Menu
            usageMap[10] = START_BUTTON_USAGE_ID; // View
            usageMap[12] = DPAD_UP_USAGE_ID;
            usageMap[13] = DPAD_DOWN_USAGE_ID;
            usageMap[14] = DPAD_LEFT_USAGE_ID;
            usageMap[15] = DPAD_RIGHT_USAGE_ID;

            leftAnalogXMap = kHIDUsage_GD_X;
            leftAnalogYMap = kHIDUsage_GD_Y;
            leftTriggerAnalogMap = kHIDUsage_GD_Ry;
            rightAnalogXMap = kHIDUsage_GD_Z;
            rightAnalogYMap = kHIDUsage_GD_Rx;
            rightTriggerAnalogMap = kHIDUsage_GD_Rz;
        }
        else if ((vendorId == 0x0E6F && productId == 0x0113) || // AfterglowGamepadforXbox360
                 (vendorId == 0x0E6F && productId == 0x0213) || // AfterglowGamepadforXbox360
                 (vendorId == 0x1BAD && productId == 0xF900) || // AfterglowGamepadforXbox360
                 (vendorId == 0x0738 && productId == 0xCB29) || // AviatorforXbox360PC
                 (vendorId == 0x15E4 && productId == 0x3F10) || // BatarangwiredcontrollerXBOX
                 (vendorId == 0x146B && productId == 0x0601) || // BigbenControllerBB7201
                 (vendorId == 0x0738 && productId == 0xF401) || // Controller
                 (vendorId == 0x0E6F && productId == 0xF501) || // Controller
                 (vendorId == 0x1430 && productId == 0xF801) || // Controller
                 (vendorId == 0x1BAD && productId == 0x028E) || // Controller
                 (vendorId == 0x1BAD && productId == 0xFA01) || // Controller
                 (vendorId == 0x12AB && productId == 0x0004) || // DDRUniverse2Mat
                 (vendorId == 0x24C6 && productId == 0x5B00) || // Ferrari458Racingwheel
                 (vendorId == 0x1430 && productId == 0x4734) || // GH4Guitar
                 (vendorId == 0x046D && productId == 0xC21D) || // GamepadF310
                 (vendorId == 0x0E6F && productId == 0x0301) || // GamepadforXbox360
                 (vendorId == 0x0E6F && productId == 0x0401) || // GamepadforXbox360Z
                 (vendorId == 0x12AB && productId == 0x0302) || // GamepadforXbox360ZZ
                 (vendorId == 0x1BAD && productId == 0xF902) || // GamepadforXbox360ZZZ
                 (vendorId == 0x1BAD && productId == 0xF901) || // GamestopXbox360Controller
                 (vendorId == 0x1430 && productId == 0x474C) || // GuitarHeroforPCMAC
                 (vendorId == 0x1BAD && productId == 0xF501) || // HORIPADEX2TURBO
                 (vendorId == 0x1BAD && productId == 0x0003) || // HarmonixDrumKitforXbox360
                 (vendorId == 0x1BAD && productId == 0x0002) || // HarmonixGuitarforXbox360
                 (vendorId == 0x0F0D && productId == 0x000A) || // HoriCoDOA4FightStick
                 (vendorId == 0x0F0D && productId == 0x000D) || // HoriFightingStickEx2
                 (vendorId == 0x0F0D && productId == 0x0016) || // HoriRealArcadeProEx
                 (vendorId == 0x24C6 && productId == 0x5501) || // HoriRealArcadeProVXSA
                 (vendorId == 0x24C6 && productId == 0x5506) || // HoriSOULCALIBURVStick
                 (vendorId == 0x1BAD && productId == 0xF02D) || // JoytechNeoSe
                 (vendorId == 0x162E && productId == 0xBEEF) || // JoytechNeoSeTake2
                 (vendorId == 0x046D && productId == 0xC242) || // LogitechChillStream
                 (vendorId == 0x046D && productId == 0xC21E) || // LogitechF510
                 (vendorId == 0x1BAD && productId == 0xFD01) || // MadCatz360
                 (vendorId == 0x0738 && productId == 0x4740) || // MadCatzBeatPad
                 (vendorId == 0x1BAD && productId == 0xF025) || // MadCatzCallofDutyGamePad
                 (vendorId == 0x1BAD && productId == 0xF027) || // MadCatzFPSProGamePad
                 (vendorId == 0x1BAD && productId == 0xF021) || // MadCatzGhostReconFSGamePad
                 (vendorId == 0x0738 && productId == 0x4736) || // MadCatzMicroConGamePadPro
                 (vendorId == 0x1BAD && productId == 0xF036) || // MadCatzMicroConGamePadProZ
                 (vendorId == 0x0738 && productId == 0x9871) || // MadCatzPortableDrumKit
                 (vendorId == 0x0738 && productId == 0x4728) || // MadCatzStreetFighterIVFightPad
                 (vendorId == 0x0738 && productId == 0x4718) || // MadCatzStreetFighterIVFightStickSE
                 (vendorId == 0x0738 && productId == 0x4716) || // MadCatzXbox360Controller
                 (vendorId == 0x0738 && productId == 0x4726) || // MadCatzXbox360Controller
                 (vendorId == 0x0738 && productId == 0xBEEF) || // MadCatzXbox360Controller
                 (vendorId == 0x1BAD && productId == 0xF016) || // MadCatzXbox360Controller
                 (vendorId == 0x0738 && productId == 0xB726) || // MadCatzXboxcontrollerMW2
                 (vendorId == 0x045E && productId == 0x028E) || // MicrosoftXbox360Controller
                 (vendorId == 0x045E && productId == 0x0719) || // MicrosoftXbox360Controller
                 (vendorId == 0x12AB && productId == 0x0301) || // PDPAFTERGLOWAX1
                 (vendorId == 0x0E6F && productId == 0x0105) || // PDPDancePad
                 (vendorId == 0x0E6F && productId == 0x0201) || // PelicanTSZ360Pad
                 (vendorId == 0x15E4 && productId == 0x3F00) || // PowerAMiniProElite
                 (vendorId == 0x24C6 && productId == 0x5300) || // PowerAMiniProEliteGlow
                 (vendorId == 0x1BAD && productId == 0xF504) || // REALARCADEPROEX
                 (vendorId == 0x1BAD && productId == 0xF502) || // REALARCADEProVX
                 (vendorId == 0x1689 && productId == 0xFD00) || // RazerOnza
                 (vendorId == 0x1689 && productId == 0xFD01) || // RazerOnzaTournamentEdition
                 (vendorId == 0x1430 && productId == 0x4748) || // RedOctaneGuitarHeroXplorer
                 (vendorId == 0x0E6F && productId == 0x011F) || // RockCandyGamepadforXbox360
                 (vendorId == 0x12AB && productId == 0x0006) || // RockRevolutionforXbox360
                 (vendorId == 0x0738 && productId == 0xCB02) || // SaitekCyborgRumblePadPCXbox360
                 (vendorId == 0x0738 && productId == 0xCB03) || // SaitekP3200RumblePadPCXbox360
                 (vendorId == 0x1BAD && productId == 0xF028) || // StreetFighterIVFightPad
                 (vendorId == 0x0738 && productId == 0x4738) || // StreetFighterIVFightStickTE
                 (vendorId == 0x0738 && productId == 0xF738) || // SuperSFIVFightStickTES
                 (vendorId == 0x1BAD && productId == 0xF903) || // TronXbox360controller
                 (vendorId == 0x1BAD && productId == 0x5500) || // USBGamepad
                 (vendorId == 0x1BAD && productId == 0xF906) || // XB360MortalKombatFightStick
                 (vendorId == 0x15E4 && productId == 0x3F0A) || // XboxAirflowiredcontroller
                 (vendorId == 0x0E6F && productId == 0x0401)) // GameStop XBox 360 Controller
        {
            // TODO: check all the Xbox 360 like controllers
            usageMap[1] = A_BUTTON_USAGE_ID;
            usageMap[2] = B_BUTTON_USAGE_ID;
            usageMap[3] = X_BUTTON_USAGE_ID;
            usageMap[4] = Y_BUTTON_USAGE_ID;
            usageMap[5] = LEFT_SHOULDER_USAGE_ID;
            usageMap[6] = RIGHT_SHOULDER_USAGE_ID;
            usageMap[7] = LEFT_THUMBSTICK_USAGE_ID;
            usageMap[8] = RIGHT_THUMBSTICK_USAGE_ID;
            usageMap[9] = START_BUTTON_USAGE_ID;
            usageMap[10] = BACK_BUTTON_USAGE_ID;
            usageMap[12] = DPAD_UP_USAGE_ID;
            usageMap[13] = DPAD_DOWN_USAGE_ID;
            usageMap[14] = DPAD_LEFT_USAGE_ID;
            usageMap[15] = DPAD_RIGHT_USAGE_ID;

            leftAnalogXMap = kHIDUsage_GD_X;
            leftAnalogYMap = kHIDUsage_GD_Y;
            leftTriggerAnalogMap = kHIDUsage_GD_Z;
            rightAnalogXMap = kHIDUsage_GD_Rx;
            rightAnalogYMap = kHIDUsage_GD_Ry;
            rightTriggerAnalogMap = kHIDUsage_GD_Rz;
        }
        else // Generic (based on Logitech Rum/blePad 2)
        {
            usageMap[1] = X_BUTTON_USAGE_ID;
            usageMap[2] = A_BUTTON_USAGE_ID;
            usageMap[3] = B_BUTTON_USAGE_ID;
            usageMap[4] = Y_BUTTON_USAGE_ID;
            usageMap[5] = LEFT_SHOULDER_USAGE_ID;
            usageMap[6] = RIGHT_SHOULDER_USAGE_ID;
            usageMap[7] = LEFT_TRIGGER_USAGE_ID;
            usageMap[8] = RIGHT_TRIGGER_USAGE_ID;
            usageMap[9] = BACK_BUTTON_USAGE_ID;
            usageMap[10] = START_BUTTON_USAGE_ID;
            usageMap[11] = LEFT_THUMBSTICK_USAGE_ID;
            usageMap[12] = RIGHT_THUMBSTICK_USAGE_ID;

            leftAnalogXMap = kHIDUsage_GD_X;
            leftAnalogYMap = kHIDUsage_GD_Y;
            leftTriggerAnalogMap = kHIDUsage_GD_Rx;
            rightAnalogXMap = kHIDUsage_GD_Z;
            rightAnalogYMap = kHIDUsage_GD_Rz;
            rightTriggerAnalogMap = kHIDUsage_GD_Ry;
        }

        CFArrayRef elementArray = IOHIDDeviceCopyMatchingElements(device, NULL, kIOHIDOptionsTypeNone);

        for (CFIndex i = 0; i < CFArrayGetCount(elementArray); i++)
        {
            IOHIDElementRef element = (IOHIDElementRef)CFArrayGetValueAtIndex(elementArray, i);
            IOHIDElementCookie cookie = IOHIDElementGetCookie(element);

            elements.insert(std::make_pair(cookie, GamepadElement(element)));
        }
        
        CFRelease(elementArray);

        IOHIDDeviceRegisterInputValueCallback(device, deviceInput, this);
    }

    const std::string& getName() const
    {
        return name;
    }

    uint64_t getUniqueId() const
    {
        return uniqueId;
    }

    uint64_t getVendorId() const
    {
        return vendorId;
    }

    uint64_t getProductId() const
    {
        return productId;
    }

    const std::map<IOHIDElementCookie, GamepadElement>& getElements()
    {
        return elements;
    }

    const GamepadElement* getElementByCookie(IOHIDElementCookie cookie) const
    {
        auto i = elements.find(cookie);

        if (i != elements.end())
        {
            return &i->second;
        }

        return nullptr;
    }

    const UsageID* getUsageMap() const { return usageMap; }

protected:
    IOHIDDeviceRef device = Nil;
    std::map<IOHIDElementCookie, GamepadElement> elements;
    std::string name;
    uint64_t uniqueId = 0;
    uint64_t uniqueDeviceId = 0;
    uint64_t vendorId = 0;
    uint64_t productId = 0;
    UsageID usageMap[24];
    uint32_t leftAnalogXMap = 0;
    uint32_t leftAnalogYMap = 0;
    uint32_t leftTriggerAnalogMap = 0;
    uint32_t rightAnalogXMap = 0;
    uint32_t rightAnalogYMap = 0;
    uint32_t rightTriggerAnalogMap = 0;
};

std::map<IOHIDDeviceRef, std::shared_ptr<Gamepad>> gamepads;

static void deviceInput(void* ctx, IOReturn inResult, void* inSender, IOHIDValueRef value)
{
    Gamepad* gamepad = reinterpret_cast<Gamepad*>(ctx);

    if (gamepad)
    {
        IOHIDElementRef element = IOHIDValueGetElement(value);
        IOHIDElementCookie cookie = IOHIDElementGetCookie(element);

        const GamepadElement* gamepadElement = gamepad->getElementByCookie(cookie);

        if (gamepadElement)
        {
            CFIndex integerValue = IOHIDValueGetIntegerValue(value);

            if (gamepadElement->getType() == GamepadElement::Type::BUTTON)
            {
                std::cout << usageToString(gamepad->getUsageMap()[gamepadElement->getUsage()]) << " button input: " << integerValue << std::endl;
            }
            else if (gamepadElement->getType() == GamepadElement::Type::HAT)
            {
                std::cout << "Axis value: " << gamepadElement->normalizeValue(integerValue) << std::endl;
            }
            else if (gamepadElement->getType() == GamepadElement::Type::ANALOG)
            {
                //std::cout << "Analog value: " << gamepadElement->normalizeValue(integerValue) << std::endl;
            }
        }
    }
}

static void deviceAdded(void* ctx, IOReturn inResult, void* inSender, IOHIDDeviceRef device)
{
    std::cout << "Device added" << std::endl;

    gamepads.insert(std::make_pair(device, std::make_shared<Gamepad>(device)));
}

static void deviceRemoved(void *ctx, IOReturn inResult, void *inSender, IOHIDDeviceRef device)
{
    std::cout << "Device removed" << std::endl;

    auto i = gamepads.find(device);

    if (i != gamepads.end())
    {
        gamepads.erase(i);
    }
}

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSArray* criteria = @[
                          @{ @kIOHIDDeviceUsagePageKey : @(kHIDPage_GenericDesktop),
                              @kIOHIDDeviceUsageKey : @(kHIDUsage_GD_Joystick) },
                          @{ @kIOHIDDeviceUsagePageKey : @(kHIDPage_GenericDesktop),
                              @kIOHIDDeviceUsageKey : @(kHIDUsage_GD_GamePad) },
                          @{ @kIOHIDDeviceUsagePageKey : @(kHIDPage_GenericDesktop),
                              @kIOHIDDeviceUsageKey : @(kHIDUsage_GD_MultiAxisController) }
                          ];

    hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);

    IOHIDManagerSetDeviceMatchingMultiple(hidManager, (CFArrayRef)criteria);
    IOReturn ret = IOHIDManagerOpen(hidManager, kIOHIDOptionsTypeNone);
    if (ret != kIOReturnSuccess)
    {
        IOHIDManagerClose(hidManager, kIOHIDOptionsTypeNone);
        CFRelease(hidManager);
        std::cout << "Failed to initialize manager" << std::endl;
    }
    else
    {
        std::cout << "Manager created" << std::endl;

        IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        IOHIDManagerRegisterDeviceMatchingCallback(hidManager, deviceAdded, nullptr);
        IOHIDManagerRegisterDeviceRemovalCallback(hidManager, deviceRemoved, nullptr);
    }
}

-(void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Insert code here to tear down your application
}


@end
