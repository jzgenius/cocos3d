/*
 * CC3GLSLVariable.m
 *
 * cocos3d 2.0.0
 * Author: Bill Hollings
 * Copyright (c) 2011-2013 The Brenwill Workshop Ltd. All rights reserved.
 * http://www.brenwill.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * http://en.wikipedia.org/wiki/MIT_License
 * 
 * See header file CC3GLSLVariable.h for full API documentation.
 */

#import "CC3GLSLVariable.h"
#import "CC3ShaderProgram.h"
#import "CC3NodeVisitor.h"
#import "CC3OpenGLFoundation.h"
#import "CC3OpenGLUtility.h"
#import "CC3OpenGL.h"


NSString* NSStringFromCC3GLSLVariableScope(CC3GLSLVariableScope scope) {
	switch (scope) {
		case kCC3GLSLVariableScopeUnknown: return @"kCC3GLSLVariableScopeUnknown";
		case kCC3GLSLVariableScopeScene: return @"kCC3GLSLVariableScopeScene";
		case kCC3GLSLVariableScopeNode: return @"kCC3GLSLVariableScopeNode";
		case kCC3GLSLVariableScopeDraw: return @"kCC3GLSLVariableScopeDraw";
			
		default: return [NSString stringWithFormat: @"Unknown variable scope (%u)", scope];
	}
}


#pragma mark -
#pragma mark CC3GLSLVariable

@implementation CC3GLSLVariable

@synthesize program=_program, index=_index, location=_location, name=_name;
@synthesize type=_type, size=_size, semantic=_semantic, semanticIndex=_semanticIndex;
@synthesize scope=_scope, isGLStateKnown=_isGLStateKnown;

-(void) dealloc {
	_program = nil;			// not retained
	[_name release];
	[super dealloc];
}


#pragma mark Allocation and initialization

-(id) initInProgram: (CC3ShaderProgram*) program atIndex: (GLuint) index {
	if ( (self = [super init]) ) {
		_index = index;
		_semantic = kCC3SemanticNone;
		_semanticIndex = 0;
		_scope = kCC3GLSLVariableScopeUnknown;
		_program = program;			// not retained
		[self populateFromProgram];
	}
	return self;
}

+(id) variableInProgram: (CC3ShaderProgram*) program atIndex: (GLuint) index {
	return [[[self alloc] initInProgram: program atIndex: index] autorelease];
}

-(id) copyWithZone: (NSZone*) zone { return [self copyWithZone: zone asClass: self.class]; }

-(id) copyAsClass: (Class) aClass { return [self copyWithZone: nil asClass: aClass]; }

-(id) copyWithZone: (NSZone*) zone asClass: (Class) aClass {
	CC3GLSLVariable* aCopy = [[aClass allocWithZone: zone] initInProgram: _program atIndex: _index];
	[aCopy populateFrom: self];
	return aCopy;
}

-(void) populateFrom: (CC3GLSLVariable*) another {
	// _program & _index set during init
	[_name release];
	_name = [another.name retain];

	_location = another.location;
	_type = another.type;
	_size = another.size;
	_semantic = another.semantic;
	_semanticIndex = another.semanticIndex;
	_scope = another.scope;
	_isGLStateKnown = another.isGLStateKnown;
}

-(void) populateFromProgram {
	_semantic = kCC3SemanticNone;
	_semanticIndex = 0;
	_isGLStateKnown = NO;
	[CC3OpenGL.sharedGL populateShaderProgramVariable: self];
	[self normalizeName];
}

/** Ensures this variable has a valid name, by removing the subscript suffix ([0]), if it exists. */
-(void) normalizeName {
	NSString* subStr = @"[0]";
	NSInteger subStartIdx = _name.length - subStr.length;
	if ( _name && (subStartIdx > 0) && [[_name substringFromIndex: subStartIdx] isEqualToString: subStr] ) {
		NSString* name = [_name substringToIndex: subStartIdx];
		[_name release];
		[_name = name retain];		// retained
	}
}

-(NSString*) description { return [NSString stringWithFormat: @"%@ named %@", self.class, _name]; }

-(NSString*) fullDescription {
	NSMutableString* desc = [NSMutableString stringWithCapacity: 200];
	[desc appendFormat: @"%@", self.description];
	[desc appendFormat: @"\n\t\tLocation: %i", _location];
	[desc appendFormat: @"\n\t\tIndex: %u", _index];
	[desc appendFormat: @"\n\t\tType: %@", NSStringFromGLEnum(_type)];
	[desc appendFormat: @"\n\t\tSize: %i", _size];
	[desc appendFormat: @"\n\t\tSemantic: %@ (%u)", self.semanticName, _semantic];
	[desc appendFormat: @"\n\t\tSemantic index: %u", _semanticIndex];
	[desc appendFormat: @"\n\t\tScope: %@", NSStringFromCC3GLSLVariableScope(_scope)];
	return desc;
}

-(NSString*) semanticName { return [_program.semanticDelegate nameOfSemantic: _semantic]; }

@end


#pragma mark -
#pragma mark CC3GLSLAttribute

@implementation CC3GLSLAttribute

-(GLenum) type { return super.type; }	// Keep compiler happy

@end


#pragma mark -
#pragma mark CC3GLSLUniform

@implementation CC3GLSLUniform

-(void) dealloc {
	free(_varValue);
	free(_glVarValue);
	[super dealloc];
}

-(GLenum) type { return super.type; }	// Keep compiler happy

// Protected property for copying
-(GLvoid*) varValue { return _varValue; }

#pragma mark Allocation and initialization

-(id) initInProgram: (CC3ShaderProgram*) program atIndex: (GLuint) index {
	// Initialized before populateFromProgram is invoked in parent initializer.
	_varLen = 0;
	_varValue = NULL;
	return [super initInProgram: program atIndex: index];
}

-(void) populateFrom: (CC3GLSLUniform*) another {
	[super populateFrom: another];
	_varLen = CC3GLElementTypeSize(_type) * _size;
	free(_varValue);
	_varValue = calloc(_varLen, 1);
	free(_glVarValue);
	_glVarValue = calloc(_varLen, 1);
}


#pragma mark Accessing uniform values

-(void) setFloat: (GLfloat) value { [self setFloat: value at: 0]; }

-(void) setFloat: (GLfloat) value at: (GLuint) index {
	[self setVector4: CC3Vector4Make(value, 0.0, 0.0, 1.0) at: index];
}

-(void) setPoint: (CGPoint) value { [self setPoint: value at: 0]; }

-(void) setPoint: (CGPoint) value at: (GLuint) index {
	[self setVector4: CC3Vector4Make(value.x, value.y, 0.0, 1.0) at: index];
}

-(void) setVector: (CC3Vector) value { [self setVector: value at: 0]; }

-(void) setVector: (CC3Vector) value at: (GLuint) index {
	[self setVector4: CC3Vector4Make(value.x, value.y, value.z, 1.0) at: index];
}

-(void) setVector4: (CC3Vector4) value { [self setVector4: value at: 0]; }

-(void) setVector4: (CC3Vector4) value at: (GLuint) index {
	CC3Assert(index < _size, @"%@ could not set value because index %u is out of bounds", self, index);
	
	switch (_type) {
			
		case GL_FLOAT:
			((GLfloat*)_varValue)[index] = *(GLfloat*)&value;
			return;
		case GL_FLOAT_VEC2:
			((CGPoint*)_varValue)[index] = *(CGPoint*)&value;
			return;
		case GL_FLOAT_VEC3:
			((CC3Vector*)_varValue)[index] = *(CC3Vector*)&value;
			return;
		case GL_FLOAT_VEC4:
		case GL_FLOAT_MAT2:
			((CC3Vector4*)_varValue)[index] = value;
			return;
			
		case GL_FLOAT_MAT3:
		case GL_FLOAT_MAT4:
			CC3Assert(NO, @"%@ attempted to set scalar or vector when matrix type %@ expected.",
					 self, NSStringFromGLEnum(_type));
			return;
			
		case GL_INT:
		case GL_INT_VEC2:
		case GL_INT_VEC3:
		case GL_INT_VEC4:
		case GL_SAMPLER_2D:
		case GL_SAMPLER_CUBE:
		case GL_BOOL:
		case GL_BOOL_VEC2:
		case GL_BOOL_VEC3:
		case GL_BOOL_VEC4:
			[self setIntVector4: CC3IntVector4Make(value.x, value.y, value.z, value.w) at: index];
			return;
			
		default:
			CC3Assert(NO, @"%@ could not set value because type %@ is not understood",
					  self, NSStringFromGLEnum(_type));
			return;
	}
	LogTrace(@"%@ setting value to %@", self.fullDescription, NSStringFromCC3Vector4( value));
}

-(void) setQuaternion: (CC3Quaternion) value { [self setQuaternion: value at: 0]; }

-(void) setQuaternion: (CC3Quaternion) value at: (GLuint) index { [self setVector4: value at: index]; }

-(void) setMatrix3x3: (CC3Matrix3x3*) value { [self setMatrix3x3: value at: 0]; }

-(void) setMatrix3x3: (CC3Matrix3x3*) value at: (GLuint) index {
	CC3Matrix3x3* varMtx = (CC3Matrix3x3*)_varValue;
	switch (_type) {
		case GL_FLOAT_MAT3:
			varMtx[index] = *value;
			return;
		default:
			CC3Assert(NO, @"%@ attempted to set 3x3 matrix when matrix type %@ expected.",
					 self, NSStringFromGLEnum(_type));
			return;
	}
}

-(void) setMatrix4x3: (CC3Matrix4x3*) value { [self setMatrix4x3: value at: 0]; }

-(void) setMatrix4x3: (CC3Matrix4x3*) value at: (GLuint) index {
	CC3Matrix4x4* varMtx = (CC3Matrix4x4*)_varValue;
	switch (_type) {
		case GL_FLOAT_MAT4:
			CC3Matrix4x4PopulateFrom4x3(&(varMtx[index]), value);
			return;
		default:
			CC3Assert(NO, @"%@ attempted to set 4x4 matrix when matrix type %@ expected.",
					  self, NSStringFromGLEnum(_type));
			return;
	}
}

-(void) setMatrix4x4: (CC3Matrix4x4*) value { [self setMatrix4x4: value at: 0]; }

-(void) setMatrix4x4: (CC3Matrix4x4*) value at: (GLuint) index {
	CC3Matrix4x4* varMtx = (CC3Matrix4x4*)_varValue;
	switch (_type) {
		case GL_FLOAT_MAT4:
			varMtx[index] = *value;
			return;
		default:
			CC3Assert(NO, @"%@ attempted to set 4x4 matrix when matrix type %@ expected.",
					 self, NSStringFromGLEnum(_type));
			return;
	}
}

-(void) setInteger: (GLint) value { [self setInteger: value at: 0]; }

-(void) setInteger: (GLint) value at: (GLuint) index {
	[self setIntVector4: CC3IntVector4Make(value, 0, 0, 0) at: index];
}

-(void) setIntPoint: (CC3IntPoint) value { [self setIntPoint: value at: 0]; }

-(void) setIntPoint: (CC3IntPoint) value at: (GLuint) index {
	[self setIntVector4: CC3IntVector4Make(value.x, value.y, 0, 0) at: index];
}

-(void) setIntVector: (CC3IntVector) value { [self setIntVector: value at: 0]; }

-(void) setIntVector: (CC3IntVector) value at: (GLuint) index {
	[self setIntVector4: CC3IntVector4Make(value.x, value.y, value.z, 0) at: index];
}

-(void) setIntVector4: (CC3IntVector4) value { [self setIntVector4: value at: 0]; }

-(void) setIntVector4: (CC3IntVector4) value at: (GLuint) index {
	CC3Assert(index < _size, @"%@ could not set value because index %u is out of bounds", self, index);
	
	switch (_type) {
			
		case GL_FLOAT:
		case GL_FLOAT_VEC2:
		case GL_FLOAT_VEC3:
		case GL_FLOAT_VEC4:
		case GL_FLOAT_MAT2:
			[self setVector4: CC3Vector4Make(value.x, value.y, value.z, value.w) at: index];
			return;
			
		case GL_FLOAT_MAT3:
		case GL_FLOAT_MAT4:
			CC3Assert(NO, @"%@ attempted to set scalar or vector when matrix type %@ expected.",
					 self, NSStringFromGLEnum(_type));
			return;
			
		case GL_INT:
		case GL_BOOL:
		case GL_SAMPLER_2D:
		case GL_SAMPLER_CUBE:
			((GLint*)_varValue)[index] = *(GLint*)&value;
			return;
		case GL_INT_VEC2:
		case GL_BOOL_VEC2:
			((CC3IntPoint*)_varValue)[index] = *(CC3IntPoint*)&value;
			return;
		case GL_INT_VEC3:
		case GL_BOOL_VEC3:
			((CC3IntVector*)_varValue)[index] = *(CC3IntVector*)&value;
			return;
		case GL_INT_VEC4:
		case GL_BOOL_VEC4:
			((CC3IntVector4*)_varValue)[index] = value;
			return;
			
		default:
			CC3Assert(NO, @"%@ could not set value because type %@ is not understood",
					  self, NSStringFromGLEnum(_type));
			return;
	}
	LogTrace(@"%@ setting value to (%i, %i, %i, %i)", self.fullDescription, value.x, value.y, value.z, value.w);
}

-(void) setBoolean: (BOOL) value { [self setBoolean: value at: 0]; }

-(void) setBoolean: (BOOL) value at: (GLuint) index { [self setInteger: (value != 0) at: index]; }

-(void) setColor: (ccColor3B) value { [self setColor: value at: 0]; }

-(void) setColor: (ccColor3B) value at: (GLuint) index {
	[self setColor4B: ccc4(value.r, value.g, value.b, 255) at: index];
}

-(void) setColor4B: (ccColor4B) value { [self setColor4B: value at: 0]; }

-(void) setColor4B: (ccColor4B) value at: (GLuint) index {
	switch (_type) {

		case GL_FLOAT:
		case GL_FLOAT_VEC2:
		case GL_FLOAT_VEC3:
		case GL_FLOAT_VEC4:
		case GL_FLOAT_MAT2:
			[self setColor4F: CCC4FFromCCC4B(value)];
			return;
			
		case GL_FLOAT_MAT3:
		case GL_FLOAT_MAT4:
			CC3Assert(NO, @"%@ attempted to set color when matrix type %@ expected.",
					 self, NSStringFromGLEnum(_type));
			return;

		case GL_INT:
		case GL_BOOL:
		case GL_INT_VEC2:
		case GL_BOOL_VEC2:
		case GL_INT_VEC3:
		case GL_BOOL_VEC3:
		case GL_INT_VEC4:
		case GL_BOOL_VEC4:
		case GL_SAMPLER_2D:
		case GL_SAMPLER_CUBE:
			[self setIntVector4: CC3IntVector4Make(value.r, value.g, value.b, value.a) at: index];
			return;
			
		default:
			CC3Assert(NO, @"%@ could not set value because type %@ is not understood",
					  self, NSStringFromGLEnum(_type));
			return;
	}
}

-(void) setColor4F: (ccColor4F) value { [self setColor4F: value at: 0]; }

-(void) setColor4F: (ccColor4F) value at: (GLuint) index {
	switch (_type) {
			
		case GL_FLOAT:
		case GL_FLOAT_VEC2:
		case GL_FLOAT_VEC3:
		case GL_FLOAT_VEC4:
		case GL_FLOAT_MAT2:
			[self setVector4: CC3Vector4Make(value.r, value.g, value.b, value.a) at: index];
			return;

		case GL_FLOAT_MAT3:
		case GL_FLOAT_MAT4:
			CC3Assert(NO, @"%@ attempted to set color when matrix type %@ expected.",
					 self, NSStringFromGLEnum(_type));
			return;

		case GL_INT:
		case GL_BOOL:
		case GL_INT_VEC2:
		case GL_BOOL_VEC2:
		case GL_INT_VEC3:
		case GL_BOOL_VEC3:
		case GL_INT_VEC4:
		case GL_BOOL_VEC4:
		case GL_SAMPLER_2D:
		case GL_SAMPLER_CUBE:
			[self setColor4B: CCC4BFromCCC4F(value)];
			return;

		default:
			CC3Assert(NO, @"%@ could not set value because type %@ is not understood",
					  self, NSStringFromGLEnum(_type));
			return;
	}
}

-(void) setValueFromUniform: (CC3GLSLUniform*) uniform {
	CC3Assert(_type == uniform.type, @"Cannot update %@ from %@ because uniforms are not of the same type",
			  uniform.fullDescription, self.fullDescription);
	CC3Assert(_size == uniform.size, @"Cannot update %@ from %@ because uniforms are not of the same size",
			  uniform.fullDescription, self.fullDescription);
	memcpy(_varValue, uniform.varValue, _varLen);
}


#pragma mark Updating the GL engine

/** Also allocate space for the uniform value. */
-(void) populateFromProgram {
	[super populateFromProgram];
	
	_varLen = CC3GLElementTypeSize(_type) * _size;
	free(_varValue);
	_varValue = calloc(_varLen, 1);
	free(_glVarValue);
	_glVarValue = calloc(_varLen, 1);
	
	[self populateInitialValue];
	
	LogTrace(@"%@ populated varValue: %p, glVarValue: %p", self, _varValue, _glVarValue);
}

/** Populates the initial values of the uniform, based on the size and type. */
-(void) populateInitialValue {
	for (GLuint vIdx = 0 ; vIdx < _size; vIdx++) {
		CC3Matrix3x3 m3x3;
		CC3Matrix4x4 m4x4;
		
		switch (_type) {
				
			case GL_FLOAT:
			case GL_FLOAT_VEC2:
			case GL_FLOAT_VEC3:
			case GL_FLOAT_VEC4:
				[self setVector4: CC3Vector4Make(0.0f, 0.0f, 0.0f, 1.0f) at: vIdx];
				return;
				
			case GL_FLOAT_MAT2:
				[self setVector4: CC3Vector4Make(1.0f, 0.0f, 0.0f, 1.0f) at: vIdx];
				return;
			case GL_FLOAT_MAT3:
				CC3Matrix3x3PopulateIdentity(&m3x3);
				[self setMatrix3x3: &m3x3 at: vIdx];
				return;
			case GL_FLOAT_MAT4:
				CC3Matrix4x4PopulateIdentity(&m4x4);
				[self setMatrix4x4: &m4x4 at: vIdx];
				return;
				
			case GL_INT:
			case GL_INT_VEC2:
			case GL_INT_VEC3:
			case GL_INT_VEC4:
			case GL_SAMPLER_2D:
			case GL_SAMPLER_CUBE:
			case GL_BOOL:
			case GL_BOOL_VEC2:
			case GL_BOOL_VEC3:
			case GL_BOOL_VEC4:
				[self setIntVector4: CC3IntVector4Make(0, 0, 0, 1) at: vIdx];
				return;
				
			default:
				CC3Assert(NO, @"%@ could not set value because type %@ is not understood",
						  self, NSStringFromGLEnum(_type));
				return;
		}
	}
	
}

-(BOOL) updateGLValueWithVisitor: (CC3NodeDrawingVisitor*) visitor {
	if ( !_isGLStateKnown || memcmp(_glVarValue, _varValue, _varLen) != 0 ) {
		memcpy(_glVarValue, _varValue, _varLen);
		[visitor.gl setShaderProgramUniformValue: self];
		_isGLStateKnown = YES;
		return YES;
	}
	return NO;
}

@end


#pragma mark -
#pragma mark CC3GLSLUniformOverride

@implementation CC3GLSLUniformOverride
-(BOOL) updateGLValueWithVisitor: (CC3NodeDrawingVisitor*) visitor { return NO; }
@end

