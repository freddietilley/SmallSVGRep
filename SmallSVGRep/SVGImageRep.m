/**
 * Copyright (c) 2017, Impending
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * @license     Berkeley Software Distribution License (BSD-License 2) http://www.opensource.org/licenses/bsd-license.php
 * @author      Freddie Tilley <freddie.tilley@impending.nl>
 * @copyright   Impending
 * @link        http://www.impending.nl
 */

#import "SVGImageRep.h"
#import <AppKit/AppKit.h>


@interface SVGNode : NSObject

+ (instancetype)nodeWithType:(NSString*)type andAttributes:(NSDictionary*)attributes;
- (instancetype)initWithType:(NSString*)type andAttributes:(NSDictionary*)attributes;

@property (nonatomic, weak) SVGNode *parent;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSDictionary *attributes;
@property (nonatomic, readonly) NSArray *children;

- (void)addChild:(SVGNode*)child;

@end

NSDictionary *GetStylePropertiesFromString(NSString *styleString);
NSArray *GetPathTokensFromString(NSString *pathString);
NSArray *GetPolyPointsFromString(NSString *polyString);
NSColor *NSColorFromSVGColorString(NSString *svgColor);

@interface SVGDocument: SVGNode

@property(readwrite,assign) CGFloat width;
@property(readwrite,assign) CGFloat height;

@end

@interface SVGImageRep ()

@property (readwrite, retain) SVGDocument *doc;

@end

@interface SVGElement: SVGNode

@property(readwrite,copy) NSBezierPath *path;
@property(readwrite,copy) NSColor *fillColor;
@property(readwrite,copy) NSColor *strokeColor;
@property(readwrite,assign) CGFloat strokeWidth;

@end

@interface SVGDocumentParser: NSObject  <NSXMLParserDelegate> {
    @private
    SVGDocument *_document;
    SVGNode *_parentNode;
}

+ (SVGDocument *)parseData:(NSData *)svgData;

@end

@implementation SVGImageRep

+ (NSArray *)imageUnfilteredTypes
{
    NSArray *types = [NSArray arrayWithObjects: (NSString*)kUTTypeScalableVectorGraphics, nil];
    return types;
}

+ (NSArray *)imageUnfilteredFileTypes
{
    NSArray *tags = (__bridge NSArray *)
        CFAutorelease((UTTypeCopyAllTagsWithClass(kUTTypeScalableVectorGraphics, CFSTR("public.filename-extension"))));
    return tags;
}

+ (BOOL)canInitWithData:(NSData *)data
{
    //self.svg = [[PocketSVG alloc] initFromSVGData: data];
    //NSLog(@"can init with data");
    return YES;
}

+ (instancetype)imageRepWithData:(NSData*)data {
    return [[[self class] alloc] initWithData: data];
}

- (instancetype)initWithData:(NSData *)data
{
    self = [super init];

    if (self != nil) {
        _doc = [SVGDocumentParser parseData: data];
    }

    return self;
}

- (NSSize)size {
    return NSMakeSize(100.0f, 100.0f);
}

- (void)drawElement:(SVGElement*)element withTransform:(NSAffineTransform*)transform
{
    NSBezierPath *path = [element.path copy];

    [path transformUsingAffineTransform: transform];

    if (element.fillColor != nil) {
        [element.fillColor set];
        [path fill];
    } else {
        if (element.parent != nil && [element.parent isKindOfClass: [SVGElement class]] && ((SVGElement*)element.parent).fillColor != nil) {
            [((SVGElement*)element.parent).fillColor set];
            [path fill];
        } else {
            [[NSColor blackColor] set];
            [path fill];
        }
    }

    if (element.strokeColor != nil) {
        [element.strokeColor set];
        path.lineWidth = element.strokeWidth; //(element.strokeWidth * scaleX);
        [path stroke];
    }

    for (SVGElement *el in element.children) {
        [self drawElement: el withTransform: transform];
    }
}

- (BOOL)drawInRect:(NSRect)rect
{
    [[NSColor blackColor] set];

    CGFloat scaleX = 1.0f;
    CGFloat scaleY = 1.0f;
    NSAffineTransform *transform = [NSAffineTransform transform];

    self.maintainAspectRatio = YES;

    if (_maintainAspectRatio)
    {
        CGFloat boundingBoxAspectRatio = self.size.width / self.size.height;
        CGFloat targetAspectRatio = rect.size.width / rect.size.height;
        CGFloat scaleFactor = 1.0f;

        if (boundingBoxAspectRatio > targetAspectRatio) {
            scaleFactor = rect.size.width / self.size.width;
        } else {
            scaleFactor = rect.size.height / self.size.height;
        }

        [transform scaleXBy: scaleFactor yBy: scaleFactor*-1.0f];
    } else {
        scaleX = rect.size.width / self.size.width;
        scaleY = rect.size.height / self.size.height;

        scaleY *= -1.0f;
        [transform scaleXBy: scaleX yBy: scaleY];
    }

    [transform translateXBy: 0 yBy: -self.size.height];

    for (SVGElement *el in _doc.children)
    {
        [self drawElement: el withTransform: transform];
        /*
        NSBezierPath *path = [el.path copy];

        //if (el.strokeColor != nil) {
            //path.lineWidth = el.strokeWidth;
        //}

        [path transformUsingAffineTransform: transform];

        if (el.fillColor != nil) {
            [el.fillColor set];
            [path fill];
        }

        if (el.strokeColor != nil) {
            [el.strokeColor set];
            path.lineWidth = (el.strokeWidth * scaleX);
            [path stroke];
        }
        */
    }

    return YES;
}

@end

typedef struct
{
    unichar lastCommand;
    NSPoint lastControlPoint;
    BOOL validLastControlPoint;
} TokenContext;

@interface Token : NSObject {
    @private
    unichar        _command;
    NSMutableArray *_values;
}

+ (instancetype)tokenWithCommand:(unichar)commandChar;
- (instancetype)initWithCommand:(unichar)commandChar;
- (void)addValue:(CGFloat)value;

- (CGFloat)parameter:(NSUInteger)index;
- (NSInteger)valence;

- (NSUInteger)pointCount;
- (NSPoint)pointAtIndex:(NSUInteger)index;

@property(nonatomic, assign) unichar command;

@end

@interface NSBezierPath (SVGExtensions)

+ (instancetype)bezierPathWithSVGPathData:(NSString*)pathData;
+ (instancetype)bezierPathWithSVGPolylineData:(NSString*)polylineData;

- (void)addQuadCurveToPoint:(NSPoint)endPoint controlPoint:(NSPoint)controlPoint;

@end

#pragma mark - Token class implementation

@implementation Token

+ (instancetype)tokenWithCommand:(unichar)commandChar {
    return [[self alloc] initWithCommand: commandChar];
}

- (instancetype)initWithCommand:(unichar)commandChar {
    self = [self init];
    if (self) {
        _command = commandChar;
        _values = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)addValue:(CGFloat)value {
    #if CGFLOAT_IS_DOUBLE
    [_values addObject:[NSNumber numberWithDouble: value]];
    #else
    [_values addObject:[NSNumber numberWithFloat: value]];
    #endif
}

- (CGFloat)parameter:(NSUInteger)index {
    #if CGFLOAT_IS_DOUBLE
    return [[_values objectAtIndex: index] doubleValue];
    #else
    return [[_values objectAtIndex: index] floatValue];
    #endif
}

- (NSInteger)valence { return [_values count]; }

- (NSUInteger)pointCount {
    return floor((_values.count / 2));
}

- (NSPoint)pointAtIndex:(NSUInteger)index
{
    index = index * 2;

    if ((index + 1) < _values.count) {
        return NSMakePoint([self parameter: index], [self parameter: index+1]);
    }

    return NSZeroPoint;
}

- (void)_appendMCommand:(NSBezierPath*)path withContext:(TokenContext*)context
{
    context->validLastControlPoint = NO;

    for (NSUInteger i = 0; i < self.pointCount; i++) {
        NSPoint point = [self pointAtIndex: i];

        if (i == 0) {
            if (_command == 'M') {
                [path moveToPoint: point];
            } else {
                [path relativeMoveToPoint: point];
            }
        } else {
            if (_command == 'M') {
                [path lineToPoint: point];
            } else {
                [path relativeLineToPoint: point];
            }
        }
    }
}

- (void)_appendLCommand:(NSBezierPath*)path withContext:(TokenContext*)context
{
    for (NSUInteger i = 0; i < self.pointCount; i++) {
        if (_command == 'L') {
            [path lineToPoint: [self pointAtIndex: i]];
        } else {
            [path relativeLineToPoint: [self pointAtIndex: i]];
        }
    }
}

- (void)_appendHCommand:(NSBezierPath*)path withContext:(TokenContext*)context
{
    for (NSUInteger i = 0; i < self.valence; i++) {
        NSPoint point = path.currentPoint;
        CGFloat x = [self parameter: i];

        point.x = (_command == 'H' ? x : point.x + x);
        [path lineToPoint: point];
    }
}

- (void)_appendVCommand:(NSBezierPath*)path withContext:(TokenContext*)context
{
    for (NSUInteger i = 0; i < self.valence; i++) {
        NSPoint point = path.currentPoint;
        CGFloat y = [self parameter: i];

        point.y = (_command == 'V' ? y : point.y + y);
        [path lineToPoint: point];
    }
}

- (void)_appendCCommand:(NSBezierPath*)path withContext:(TokenContext*)context
{
    NSUInteger index = 0;

    while ((index + 2) < self.pointCount)
    {
        NSPoint cp1 = [self pointAtIndex: index++];
        NSPoint cp2 = [self pointAtIndex: index++];
        NSPoint point = [self pointAtIndex: index++];

        if (_command == 'C') {
            [path curveToPoint: point controlPoint1: cp1 controlPoint2: cp2];
        } else {
            NSPoint lastPoint = [path currentPoint];

            [path relativeCurveToPoint: point controlPoint1: cp1 controlPoint2: cp2];

            cp2.x += lastPoint.x;
            cp2.y += lastPoint.y;
        }

        context->lastControlPoint = cp2;
        context->validLastControlPoint = YES;
    }
}

- (void)_appendSCommand:(NSBezierPath*)path withContext:(TokenContext*)context
{
    NSUInteger index = 0;

    while ((index + 1) < self.pointCount)
    {
        NSPoint lastPoint = path.currentPoint;
        NSPoint cp1 = NSMakePoint((lastPoint.x - context->lastControlPoint.x),
                                  (lastPoint.y - context->lastControlPoint.y));
        NSPoint cp2 = [self pointAtIndex: index++];
        NSPoint point = [self pointAtIndex: index++];

        if (_command == 'S') {
            cp1.x += lastPoint.x;
            cp1.y += lastPoint.y;

            [path curveToPoint: point controlPoint1: cp1 controlPoint2: cp2];
        } else {
            [path relativeCurveToPoint: point controlPoint1: cp1 controlPoint2: cp2];

            cp2.x += lastPoint.x;
            cp2.y += lastPoint.y;
        }

        context->lastControlPoint = cp2;
        context->validLastControlPoint = YES;
    }
}

- (void)_appendQCommand:(NSBezierPath*)path withContext:(TokenContext*)context
{
    NSUInteger index = 0;

    while ((index + 1) < self.pointCount)
    {
        NSPoint cp1 = [self pointAtIndex: index++];
        NSPoint point = [self pointAtIndex: index++];

        if (_command == 'Q') {
            [path addQuadCurveToPoint: point controlPoint: cp1];
        } else {
            NSPoint lastPoint = [path currentPoint];

            cp1.x += lastPoint.x;
            cp1.y += lastPoint.y;

            point.x += lastPoint.x;
            point.y += lastPoint.y;

            [path addQuadCurveToPoint: point controlPoint: cp1];
        }

        context->lastControlPoint = cp1;
        context->validLastControlPoint = YES;
    }
}

- (void)_appendTCommand:(NSBezierPath*)path withContext:(TokenContext*)context
{
    NSUInteger index = 0;

    while (index < self.pointCount)
    {
        //NSPoint cp1 = [self pointAtIndex: index++];
        unichar prevCommand = context->lastCommand;
        NSPoint lastPoint = [path currentPoint];
        NSPoint prevCtrl = context->lastControlPoint;
        NSPoint cp = lastPoint;
        NSPoint point = [self pointAtIndex: index++];

        if (prevCommand == 'Q' || prevCommand == 'q' || prevCommand == 'T' ||
            prevCommand == 't')
        {
            cp.x = lastPoint.x + (lastPoint.x - prevCtrl.x);
            cp.y = lastPoint.y + (lastPoint.y - prevCtrl.y);
        }

        if (_command == 'T') {
            NSLog(@"T command to %@ with cp: %@", NSStringFromPoint(point), NSStringFromPoint(cp));
            [path addQuadCurveToPoint: point controlPoint: cp];
        } else {
            cp.x += lastPoint.x;
            cp.y += lastPoint.y;

            point.x += lastPoint.x;
            point.y += lastPoint.y;

            [path addQuadCurveToPoint: point controlPoint: cp];
        }

        context->lastControlPoint = cp;
        context->validLastControlPoint = YES;
    }
}

- (void)appendTokenToPath:(NSBezierPath*)path withContext:(TokenContext*)context
{
    NSAssert(context != NULL, @"Required token context missing!");

    switch(_command)
    {
        case 'M':
        case 'm':
            [self _appendMCommand: path withContext: context];
            break;
        case 'L':
        case 'l':
            [self _appendLCommand: path withContext: context];
            break;
        case 'H':
        case 'h':
            [self _appendHCommand: path withContext: context];
            break;
        case 'V':
        case 'v':
            [self _appendVCommand: path withContext: context];
            break;
        case 'C':
        case 'c':
            [self _appendCCommand: path withContext: context];
            break;
        case 'Q':
        case 'q':
            [self _appendQCommand: path withContext: context];
            break;
        case 'T':
        case 't':
            [self _appendTCommand: path withContext: context];
            break;
        case 'S':
        case 's':
            [self _appendSCommand: path withContext: context];
            break;
        case 'Z':
        case 'z':
            [path closePath];
            break;
        default:
            break;
    }

    context->lastCommand = _command;
}

@end

@interface NSString (SVGExtensions)
- (BOOL)scanHexInt:(unsigned int *)intValue;

@end

@implementation NSString (SVGExtensions)

- (BOOL)scanHexInt:(unsigned int*)intValue
{
    if (self.length > 0) {
        NSScanner *scanner = [NSScanner scannerWithString: self];

        if ([scanner scanHexInt: intValue]) {
            return YES;
        }
    }

    *intValue = 0;
    return NO;
}

@end

@implementation NSBezierPath (SVGExtensions)

+ (instancetype)bezierPathWithSVGPathData:(NSString*)pathData
{
    NSBezierPath *path = [NSBezierPath bezierPath];
    NSArray *tokens = GetPathTokensFromString(pathData);
    TokenContext context = {};

    for (Token *token in tokens) {
        [token appendTokenToPath: path withContext: &context];
    }

    return path;
}

+ (instancetype)bezierPathWithSVGPolylineData:(NSString*)polylineData
{
    NSBezierPath *path = [NSBezierPath bezierPath];
    NSArray *points = GetPolyPointsFromString(polylineData);

    for (NSValue *value in points)
    {
        if (path.empty) {
            [path moveToPoint: value.pointValue];
        } else {
            [path lineToPoint: value.pointValue];
        }
    }

    return path;
}

- (void)addQuadCurveToPoint:(NSPoint)endPoint controlPoint:(NSPoint)controlPoint
{
    NSPoint cp1, cp2;
    NSPoint sp = self.currentPoint;

    cp1.x = sp.x + ((2.0f/3.0f) * (controlPoint.x - sp.x));
    cp1.y = sp.y + ((2.0f/3.0f) * (controlPoint.y - sp.y));

    cp2.x = endPoint.x + ((2.0f/3.0f) * (controlPoint.x - endPoint.x));
    cp2.y = endPoint.y + ((2.0f/3.0f) * (controlPoint.y - endPoint.y));

    [self curveToPoint: endPoint controlPoint1: cp1 controlPoint2: cp2];
}

@end

@implementation SVGDocument
@end


@implementation SVGElement
@end

@implementation SVGDocumentParser

+ (SVGNode *)parseData:(NSData *)svgData
{
    SVGNode *document = nil;
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData: svgData];
    SVGDocumentParser *parserDelegate = [[SVGDocumentParser alloc] init];

    parser.delegate = parserDelegate;

    if ([parser parse]) {
        document = parserDelegate->_document;
    }

    return document;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
                                        namespaceURI:(NSString *)namespaceURI
                                       qualifiedName:(NSString *)qualifiedName
                                          attributes:(NSDictionary<NSString *,NSString *> *)attributeDict
{
    if ([elementName isEqualToString: @"svg"]) {
        _parentNode = _document = [SVGDocument nodeWithType: elementName andAttributes: attributeDict];
    } else {
        SVGElement *node = [SVGElement nodeWithType: elementName andAttributes: attributeDict];

        if (_parentNode != nil) {
            [_parentNode addChild: node];

            NSBezierPath *path = nil;

            if ([node.type isEqualToString: @"path"]) {
                path = [NSBezierPath bezierPathWithSVGPathData: node.attributes[@"d"]];
            } else if ([node.type isEqualToString: @"line"])
            {
                NSPoint startPoint = NSMakePoint([node.attributes[@"x1"] floatValue],
                                                 [node.attributes[@"y1"] floatValue]);
                NSPoint endPoint = NSMakePoint([node.attributes[@"x2"] floatValue],
                                               [node.attributes[@"y2"] floatValue]);

                path = [NSBezierPath bezierPath];

                [path moveToPoint: startPoint];
                [path lineToPoint: endPoint];
            } else if ([node.type isEqualToString: @"polyline"] ||
                       [node.type isEqualToString: @"polygon"])
            {
                path = [NSBezierPath bezierPathWithSVGPolylineData: node.attributes[@"points"]];
            } else if ([node.type isEqualToString: @"circle"])
            {
                NSPoint centerPoint = NSMakePoint([node.attributes[@"cx"] floatValue],
                                                  [node.attributes[@"cy"] floatValue]);
                CGFloat radius = [node.attributes[@"r"] floatValue];

                NSRect ovalRect = NSMakeRect(centerPoint.x - radius,
                                             centerPoint.y - radius,
                                             radius * 2,
                                             radius * 2);

                path = [NSBezierPath bezierPathWithOvalInRect: ovalRect];
            } else if ([node.type isEqualToString: @"rect"])
            {
                NSRect rect = NSZeroRect;
                CGFloat xRadius = 0.0f;
                CGFloat yRadius = 0.0f;

                rect.size = NSMakeSize([node.attributes[@"width"] floatValue],
                                       [node.attributes[@"height"] floatValue]);

                if (node.attributes[@"x"] != nil) {
                    rect.origin.x = [node.attributes[@"x"] floatValue];
                }

                if (node.attributes[@"y"] != nil) {
                    rect.origin.y = [node.attributes[@"y"] floatValue];
                }

                if (node.attributes[@"rx"] != nil) {
                    xRadius = [node.attributes[@"rx"] floatValue];
                }

                if (node.attributes[@"ry"] != nil) {
                    yRadius = [node.attributes[@"ry"] floatValue];
                }

                path = [NSBezierPath bezierPathWithRoundedRect: rect
                                                       xRadius: xRadius
                                                       yRadius: yRadius];

            } else {
                //NSLog(@"unhandled node type: %@", node.type);
            }

            if (node.attributes[@"style"] != nil) {
                //NSDictionary *style = GetStylePropertiesFromString(node.attributes[@"style"]);
                //NSLog(@"scanned style properties: %@", [node.attributes[@"style"] styleProperties]);
            }

            if (node.attributes[@"fill"] != nil) {
                node.fillColor = NSColorFromSVGColorString(node.attributes[@"fill"]);
            }

            if (node.attributes[@"stroke"] != nil) {
                node.strokeColor = NSColorFromSVGColorString(node.attributes[@"stroke"]);
            }

            if (node.attributes[@"stroke-width"] != nil) {
                node.strokeWidth = [node.attributes[@"stroke-width"] floatValue];
            }

            node.path = path;
        }

        _parentNode = node;
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
                                      namespaceURI:(NSString *)namespaceURI
                                     qualifiedName:(NSString *)qName
{
    _parentNode = [_parentNode parent];
}

@end

@implementation SVGNode

+ (instancetype)nodeWithType:(NSString*)type andAttributes:(NSDictionary*)attributes {
    return [[self alloc] initWithType: type andAttributes: attributes];
}

- (instancetype)initWithType:(NSString*)type andAttributes:(NSDictionary*)attributes {
    self = [self init];
    
    if (self){
        self.type = type;
        self.attributes = attributes;
    }
    
    return self;
}

- (id)init {
    self = [super init];
    
    if (self) {
        _children = [NSMutableArray array];
    }
    
    return self;
}

- (void)addChild:(SVGNode*)child {
    [((NSMutableArray*)self.children) addObject: child];
    child.parent = self;
}

@end

NSDictionary *GetStylePropertiesFromString(NSString *styleString)
{
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];

    NSCharacterSet *charset = [NSCharacterSet characterSetWithCharactersInString:@":;\t\r\n\f "];
    NSScanner *propertyScanner = [NSScanner scannerWithString: styleString];

    NSString *scannedString = nil;
    NSString *key = nil;
    int scanCount = 0;

    propertyScanner.charactersToBeSkipped = charset;

    while ([propertyScanner scanUpToCharactersFromSet: charset intoString: &scannedString])
    {
        scanCount++;

        if ((scanCount % 2) != 0) {
            key = scannedString;
        } else {
            properties[key] = scannedString;
        }
    }

    return properties;
}

NSArray *GetPathTokensFromString(NSString *pathString)
{
    NSMutableArray *tokens = [NSMutableArray array];

    NSCharacterSet *cmdset = [NSCharacterSet characterSetWithCharactersInString: @"ZzMmLlCcQqAaHhVvSsTt"];
    NSCharacterSet *spaceset = [NSCharacterSet characterSetWithCharactersInString: @"\t\r\n\f, "];

    NSUInteger commandLocation = NSNotFound;
    unichar curchar = 0;
    Token *token = nil;

    for (NSUInteger i = 0; i < pathString.length; i++)
    {
        curchar = [pathString characterAtIndex: i];

        if ([cmdset characterIsMember: curchar])
        {
            if (commandLocation != NSNotFound) {
                NSString *commandValues = [pathString substringWithRange: NSMakeRange(commandLocation + 1,
                                                                                      i - commandLocation - 1)];
                NSScanner *floatScanner = [NSScanner scannerWithString: commandValues];
                float floatValue;
                floatScanner.charactersToBeSkipped = spaceset;

                while ([floatScanner scanFloat: &floatValue]) {
                    [token addValue: floatValue];
                }
            }

            token = [Token tokenWithCommand: curchar];
            [tokens addObject: token];

            commandLocation = i;
        }
    }

    return tokens;
}

NSArray *GetPolyPointsFromString(NSString *polyString)
{
    NSMutableArray *points = [NSMutableArray array];

    NSScanner *pointScanner = [NSScanner scannerWithString: polyString];
    pointScanner.charactersToBeSkipped = [NSCharacterSet characterSetWithCharactersInString: @"\t\r\n\f, "];
    float floatValue;
    NSPoint point;
    int scanCount = 0;

    while ([pointScanner scanFloat: &floatValue])
    {
        scanCount++;

        if ((scanCount % 2) != 0) {
            point.x = floatValue;
        } else {
            point.y = floatValue;
            [points addObject: [NSValue valueWithPoint: point]];
        }
    }

    return points;
}

NSColor *NSColorFromSVGColorString(NSString *svgColor)
{
    if ([svgColor hasPrefix: @"#"])
    {
        unsigned int redVal = 0, greenVal = 0, blueVal = 0;
        BOOL valid = NO;

        if (svgColor.length == 7)
        {
            if ([[svgColor substringWithRange: NSMakeRange(1,2)] scanHexInt: &redVal] &&
                [[svgColor substringWithRange: NSMakeRange(3,2)] scanHexInt: &greenVal] &&
                [[svgColor substringWithRange: NSMakeRange(5,2)] scanHexInt: &blueVal])
            {
                valid = YES;
            }
        } else if (svgColor.length == 4)
        {
            if ([[svgColor substringWithRange: NSMakeRange(1,1)] scanHexInt: &redVal] &&
                [[svgColor substringWithRange: NSMakeRange(2,1)] scanHexInt: &greenVal] &&
                [[svgColor substringWithRange: NSMakeRange(3,1)] scanHexInt: &blueVal])
            {
                redVal = (redVal << 4) + redVal;
                greenVal = (greenVal << 4) + greenVal;
                blueVal = (blueVal << 4) + blueVal;

                valid = YES;
            }
        }

        if (valid) {
            return [NSColor colorWithRed: (redVal/255.0f)
                                   green: (greenVal/255.0f)
                                    blue: (blueVal/255.0f)
                                   alpha: 1.0f];
        }
    } else if ([svgColor hasPrefix: @"rgb("]) {
        int redVal = 0, greenVal = 0, blueVal = 0;
        NSString *rgbString = [svgColor substringFromIndex: 4];
        NSScanner *scanner = [NSScanner scannerWithString: rgbString];
        scanner.charactersToBeSkipped = [NSCharacterSet characterSetWithCharactersInString: @" ,\r\n()"];

        if ([scanner scanInt: &redVal] && [scanner scanInt: &greenVal] && [scanner scanInt: &blueVal])
        {
            return [NSColor colorWithRed: (redVal/255.0f)
                                   green: (greenVal/255.0f)
                                    blue: (blueVal/255.0f)
                                   alpha: 1.0f];
        }
    } else {
        NSDictionary *named = @{
            @"white" : [NSColor colorWithRed: 1.0f green: 1.0f blue: 1.0f alpha: 1.0f],
            @"silver" : [NSColor colorWithRed: 0.75f green: 0.75f blue: 0.75f alpha: 1.0f],
            @"gray" : [NSColor colorWithRed: 0.5f green: 0.5f blue: 0.5f alpha: 1.0f],
            @"black" : [NSColor blackColor],
            @"red" : [NSColor redColor],
            @"maroon" : [NSColor colorWithRed: 0.5f green: 0.0f blue: 0.0f alpha: 1.0f],
            @"yellow" : [NSColor yellowColor],
            @"olive" : [NSColor colorWithRed: 0.5f green: 0.5f blue: 0.0f alpha: 1.0f],
            @"lime" : [NSColor greenColor],
            @"green" : [NSColor colorWithRed: 0.0f green: 0.5f blue: 0.0f alpha: 1.0f],
            @"aqua" : [NSColor colorWithRed: 0.0f green: 1.0f blue: 1.0f alpha: 1.0f],
            @"teal" : [NSColor colorWithRed: 0.0f green: 0.5f blue: 0.5f alpha: 1.0f],
            @"blue" : [NSColor blueColor],
            @"navy" : [NSColor colorWithRed: 0.0f green: 0.0f blue: 0.5f alpha: 1.0f],
            @"fuchsia" : [NSColor magentaColor],
            @"purple" : [NSColor purpleColor],
        };

        if ([[svgColor lowercaseString] isEqualToString: @"none"]) {
            return nil;
        } else {
            return named[[svgColor lowercaseString]];
        }
    }

    return nil;
}
