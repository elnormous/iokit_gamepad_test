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
    LEFT_THUMB_X_USAGE_ID,
    LEFT_THUMB_Y_USAGE_ID,
	RIGHT_THUMB_X_USAGE_ID,
	RIGHT_THUMB_Y_USAGE_ID,
	LEFT_TRIGGER_USAGE_ID,
	RIGHT_TRIGGER_USAGE_ID,

    DPAD_LEFT_USAGE_ID,
	DPAD_RIGHT_USAGE_ID,
	DPAD_DOWN_USAGE_ID,
	DPAD_UP_USAGE_ID,

	PAUSE_BUTTON_USAGE_ID,
	A_BUTTON_USAGE_ID,
	B_BUTTON_USAGE_ID,
	X_BUTTON_USAGE_ID,
	Y_BUTTON_USAGE_ID,
	LEFT_SHOULDER_USAGE_ID,
	RIGHT_SHOULDER_USAGE_ID,
};

uint32_t ps3UsageMap[] = {
    kHIDUsage_GD_X, // LEFT_THUMB_X_USAGE_ID
    kHIDUsage_GD_Y, // LEFT_THUMB_Y_USAGE_ID
    kHIDUsage_GD_Z, // RIGHT_THUMB_X_USAGE_ID
    kHIDUsage_GD_Rz, // RIGHT_THUMB_Y_USAGE_ID
    kHIDUsage_GD_Rx, // LEFT_TRIGGER_USAGE_ID
    kHIDUsage_GD_Ry, // RIGHT_TRIGGER_USAGE_ID

    0x00, //DPAD_LEFT_USAGE_ID
    0x00, //DPAD_RIGHT_USAGE_ID
    0x00, //DPAD_DOWN_USAGE_ID
    0x00, //DPAD_UP_USAGE_ID

    0x0A, // PAUSE_BUTTON_USAGE_ID
    0x02, // A_BUTTON_USAGE_ID
    0x03, // B_BUTTON_USAGE_ID
    0x01, // X_BUTTON_USAGE_ID
    0x04, // Y_BUTTON_USAGE_ID
    0x05, // LEFT_SHOULDER_USAGE_ID
    0x06 // RIGHT_SHOULDER_USAGE_ID
};

uint32_t ps4UsageMap[] = {
    kHIDUsage_GD_X, // LEFT_THUMB_X_USAGE_ID
	kHIDUsage_GD_Y, // LEFT_THUMB_Y_USAGE_ID
	kHIDUsage_GD_Z, // RIGHT_THUMB_X_USAGE_ID
	kHIDUsage_GD_Rz, // RIGHT_THUMB_Y_USAGE_ID
	kHIDUsage_GD_Rx, // LEFT_TRIGGER_USAGE_ID
	kHIDUsage_GD_Ry, // RIGHT_TRIGGER_USAGE_ID

    0x00, //DPAD_LEFT_USAGE_ID
    0x00, //DPAD_RIGHT_USAGE_ID
    0x00, //DPAD_DOWN_USAGE_ID
    0x00, //DPAD_UP_USAGE_ID

    0x0A, // PAUSE_BUTTON_USAGE_ID
	0x02, // A_BUTTON_USAGE_ID
	0x03, // B_BUTTON_USAGE_ID
	0x01, // X_BUTTON_USAGE_ID
	0x04, // Y_BUTTON_USAGE_ID
	0x05, // LEFT_SHOULDER_USAGE_ID
	0x06 // RIGHT_SHOULDER_USAGE_ID
};

uint32_t xb360UsageMap[] = {
    kHIDUsage_GD_X, // LEFT_THUMB_X_USAGE_ID
    kHIDUsage_GD_Y, // LEFT_THUMB_Y_USAGE_ID
    kHIDUsage_GD_Rx, // RIGHT_THUMB_X_USAGE_ID
    kHIDUsage_GD_Ry, // RIGHT_THUMB_Y_USAGE_ID
    kHIDUsage_GD_Z, // LEFT_TRIGGER_USAGE_ID
    kHIDUsage_GD_Rz, // RIGHT_TRIGGER_USAGE_ID

    0x0E, //DPAD_LEFT_USAGE_ID
    0x0F, //DPAD_RIGHT_USAGE_ID
    0x0D, //DPAD_DOWN_USAGE_ID
    0x0C, //DPAD_UP_USAGE_ID

    0x09, // PAUSE_BUTTON_USAGE_ID
    0x01, // A_BUTTON_USAGE_ID
    0x02, // B_BUTTON_USAGE_ID
    0x03, // X_BUTTON_USAGE_ID
    0x04, // Y_BUTTON_USAGE_ID
    0x05, // LEFT_SHOULDER_USAGE_ID
    0x06 // RIGHT_SHOULDER_USAGE_ID
};

uint32_t xbOneUsageMap[] = {
    kHIDUsage_GD_X, // LEFT_THUMB_X_USAGE_ID
    kHIDUsage_GD_Y, // LEFT_THUMB_Y_USAGE_ID
    kHIDUsage_GD_Rx, // RIGHT_THUMB_X_USAGE_ID
    kHIDUsage_GD_Ry, // RIGHT_THUMB_Y_USAGE_ID
    kHIDUsage_GD_Z, // LEFT_TRIGGER_USAGE_ID
    kHIDUsage_GD_Rz, // RIGHT_TRIGGER_USAGE_ID

    0x0E, //DPAD_LEFT_USAGE_ID
    0x0F, //DPAD_RIGHT_USAGE_ID
    0x0D, //DPAD_DOWN_USAGE_ID
    0x0C, //DPAD_UP_USAGE_ID

    0x09, // PAUSE_BUTTON_USAGE_ID
    0x01, // A_BUTTON_USAGE_ID
    0x02, // B_BUTTON_USAGE_ID
    0x03, // X_BUTTON_USAGE_ID
    0x04, // Y_BUTTON_USAGE_ID
    0x05, // LEFT_SHOULDER_USAGE_ID
    0x06 // RIGHT_SHOULDER_USAGE_ID
};

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

        if (vendorId == 0x054C) // Sony
        {
            if (productId == 0x0268) // Playstation 3 controller
            {
                usageMap = ps3UsageMap;
            }
            else if (productId == 0x05C4) // Playstation 4 controller
            {
                usageMap = ps4UsageMap;
            }
        }
        else if (vendorId == 0x045E) // Microsoft
        {
            if (productId == 0x028E || productId == 0x028F) // 360 wired/wireless
            {
                usageMap = xb360UsageMap;
            }
            else if (productId == 0x02d1) // XBox One wired/wireless
            {
                usageMap = xbOneUsageMap;
            }
        }
        else
        {
            std::cout << "Unknown vendor: " << vendorId << std::endl;
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

    uint32_t* getUsageMap() const { return usageMap; }

protected:
    IOHIDDeviceRef device = Nil;
    std::map<IOHIDElementCookie, GamepadElement> elements;
    std::string name;
    uint64_t uniqueId = 0;
    uint64_t uniqueDeviceId = 0;
    uint64_t vendorId = 0;
    uint64_t productId = 0;
    uint32_t* usageMap = nullptr;
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
                if (gamepad->getUsageMap())
                {
                    if (gamepadElement->getUsage() == gamepad->getUsageMap()[A_BUTTON_USAGE_ID]) std::cout << "Button A" << std::endl;
                    else if (gamepadElement->getUsage() == gamepad->getUsageMap()[B_BUTTON_USAGE_ID]) std::cout << "Button B" << std::endl;
                    else if (gamepadElement->getUsage() == gamepad->getUsageMap()[X_BUTTON_USAGE_ID]) std::cout << "Button X" << std::endl;
                    else if (gamepadElement->getUsage() == gamepad->getUsageMap()[Y_BUTTON_USAGE_ID]) std::cout << "Button Y" << std::endl;
                }

                std::cout << "Button input: " << integerValue << std::endl;
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
