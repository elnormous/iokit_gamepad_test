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
#import "AppDelegate.h"
#import "IOKit/hid/IOHIDManager.h"

@implementation AppDelegate

IOHIDManagerRef hidManager;

static void deviceInput(void* ctx, IOReturn inResult, void* inSender, IOHIDValueRef value);

class GamepadElement
{
public:
    enum class Type
    {
        BUTTON,
        HAT,
        ANALOG
    };

    GamepadElement(IOHIDElementRef aElement):
        element(aElement)
    {
        IOHIDElementType elementType = IOHIDElementGetType(element);
        uint32_t usage = IOHIDElementGetUsage(element);
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

    float normalizeValue(CFIndex value) const
    {
        return static_cast<float>(value - min) / (max - min);
    }

protected:
    IOHIDElementRef element = Nil;
    Type type;
    CFIndex min = 0;
    CFIndex max = 0;
};

class Gamepad
{
public:
    Gamepad(IOHIDDeviceRef aDevice):
        device(aDevice)
    {
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

protected:
    IOHIDDeviceRef device = Nil;
    std::map<IOHIDElementCookie, GamepadElement> elements;
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
                std::cout << "Button input: " << integerValue << std::endl;
            }
            else if (gamepadElement->getType() == GamepadElement::Type::HAT)
            {
                std::cout << "Axis value: " << gamepadElement->normalizeValue(integerValue) << std::endl;
            }
            else if (gamepadElement->getType() == GamepadElement::Type::ANALOG)
            {
                std::cout << "Analog value: " << gamepadElement->normalizeValue(integerValue) << std::endl;
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
