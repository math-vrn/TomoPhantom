"""
Cython recipe to create an interface to C-functions (2D version)

Copyright 2017  Srikanth Nagella / Daniil Kazantsev/ Edoardo Pasca

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

"""
# cython and ctypes
import cython
import ctypes
from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free

# import numpy and the Cython declarations for numpy
import numpy as np
cimport numpy as np

from enum import Enum



# declare the interface to the C code
cdef extern float TomoP2DModel_core(float *A, int ModelSelected, int N, char* ModelParametersFilename)
cdef extern float TomoP2DObject_core(float *A, int N, char *Object, float C0, float x0, float y0, float a, float b, float phi_rot, int tt)
cdef extern float TomoP2DModelSino_core(float *A, int ModelSelected, int N, int P, float *Th, int AngTot, int CenTypeIn, char* ModelParametersFilename)
cdef extern float TomoP2DObjectSino_core(float *A, int N, int P, float *Th, int AngTot, int CenTypeIn, char *Object, float C0, float x0, float y0, float a, float b, float phi_rot, int tt)
cdef extern float checkParams2D(int *params_switch, int ModelSelected, char *ModelParametersFilename)

cdef packed struct object_2d:
    char[21] Obj
    np.float32_t C0
    np.float32_t x0
    np.float32_t y0
    np.float32_t a
    np.float32_t b
    np.float32_t phi_rot
    
class Objects2D(Enum):
    GAUSSIAN  = 'gaussian'
    PARABOLA  = 'parabola'
    PARABOLA1 = 'parabola1'
    ELLIPSE   = 'ellipse'
    CONE      = 'cone'
    RECTANGLE = 'rectangle'
    
    
@cython.boundscheck(False)
@cython.wraparound(False)
def Model(int model_id, int phantom_size, str model_parameters_filename):
    """
    To generate stationary (2D) Model(model_id, phantom_size,model_parameters_filename)
    
    Takes in a input model_id and phantom_size and returns a phantom-model of phantom_size x phantom_size of type float32 numpy array.
    
    param: model_parameters_filename -- filename for the model parameters
    param: model_id -- a model id from the functions file
    param: phantom_size -- a phantom size in each dimension.
    
    returns: numpy float32 phantom array
    """
    cdef float ret_val
    py_byte_string = model_parameters_filename.encode('UTF-8')
    cdef char* c_string = py_byte_string
    cdef np.ndarray[np.float32_t, ndim=2, mode="c"] phantom = np.zeros([phantom_size, phantom_size], dtype='float32')
    cdef np.ndarray[int, ndim=1, mode="c"] params
    params = np.ascontiguousarray(np.zeros([10], dtype=ctypes.c_int))
    checkParams2D(&params[0], model_id, c_string)
    testParams2D(params) # check parameters and terminate before running the core
    if params[3] == 1:
        ret_val = TomoP2DModel_core(&phantom[0,0], model_id, phantom_size, c_string)
    else:
        print("The selected model is temporal (3D), use 'ModelTemporal' function instead")
    return phantom
@cython.boundscheck(False)
@cython.wraparound(False)
def ModelTemporal(int model_id, int phantom_size, str model_parameters_filename):
    """
    to generate temporal (2D + time) Model(model_id, phantom_size,model_parameters_filename)
    
    Takes in a input model_id and phantom_size and returns a phantom-model of Time Frames x phantom_size x phantom_size of type float32 numpy array.
    
    param: model_parameters_filename -- filename for the model parameters
    param: model_id -- a model id from the functions file
    param: phantom_size -- a phantom size in each dimension.
    
    returns: numpy float32 phantom array
    """
    cdef float ret_val
    py_byte_string = model_parameters_filename.encode('UTF-8')
    cdef char* c_string = py_byte_string    
    cdef np.ndarray[int, ndim=1, mode="c"] params
    params = np.ascontiguousarray(np.zeros([10], dtype=ctypes.c_int))
    checkParams2D(&params[0], model_id, c_string)
    testParams2D(params) # check parameters and terminate before running the core
    cdef np.ndarray[np.float32_t, ndim=3, mode="c"] phantom = np.zeros([params[3], phantom_size, phantom_size], dtype='float32')
    if params[3] == 1:
        print("The selected model is static (2D), use 'Model' function instead")
    else:
        ret_val = TomoP2DModel_core(&phantom[0,0,0], model_id, phantom_size, c_string)
    return phantom
@cython.boundscheck(False)
@cython.wraparound(False)
def Object(int phantom_size, object_2d[:] obj_params):
    """
    Object (phantom_size,object_parameters)
    
    Takes in a input object description (list) and phantom_size and returns a phantom-object of phantom_size x phantom_size of type float32 numpy array.
    
    param: phantom_size -- a phantom size in each dimension.
    param: obj_params -- object parameters list
    
    returns: numpy float32 phantom array
    
    """
    cdef Py_ssize_t i
    cdef np.ndarray[np.float32_t, ndim=2, mode="c"] phantom = np.zeros([phantom_size, phantom_size], dtype='float32')
    cdef float ret_val
    for i in range(obj_params.shape[0]):
        ret_val = TomoP2DObject_core(&phantom[0,0], phantom_size, obj_params[i].Obj, obj_params[i].C0, 
                                     obj_params[i].x0, obj_params[i].y0, obj_params[i].a, obj_params[i].b, obj_params[i].phi_rot, 0)
    return phantom
@cython.boundscheck(False)
@cython.wraparound(False)
def ModelSino(int model_id, int image_size, int detector_size, np.ndarray[np.float32_t, ndim=1, mode="c"] angles, str model_parameters_filename):
    
    """
    function to build a sinogram of the model (2D): ModelSino (model_id, image_size, detector_size, angles, model_parameters_filename)
    
    Takes in as input model_id, image_size, detector_size and projection angles and return a 2D sinogram corresponding to the model id.
    
    param: model_parameters_filename -- filename for the model parameters
    param: model_id -- a model id from the functions file
    param: image_size -- a phantom size in each dimension.
    param: detector_size -- int detector size.
    param: angles -- a numpy array of float values with angles in radians
    param: CenTypeIn -- 1 as default [0: radon, 1:astra]
    returns: numpy float32 phantom sinograms array.    
    np.flipud(np.fliplr(sinogram.transpose()))
    """
    cdef np.ndarray[np.float32_t, ndim=2, mode="c"] sinogram = np.zeros([detector_size,angles.shape[0]], dtype='float32')
    cdef float ret_val
    py_byte_string = model_parameters_filename.encode('UTF-8')
    cdef char* c_string = py_byte_string    
    cdef int AngTot = angles.shape[0]
    cdef int CenTypeIn = 1 # astra center positioning
    cdef np.ndarray[int, ndim=1, mode="c"] params
    params = np.ascontiguousarray(np.zeros([10], dtype=ctypes.c_int))
    checkParams2D(&params[0], model_id, c_string)
    testParams2D(params) # check parameters and terminate before running the core
    if params[3] == 1:
        ret_val = TomoP2DModelSino_core(&sinogram[0,0], model_id, image_size, detector_size, &angles[0], AngTot, CenTypeIn, c_string)
    else:
        print("The selected model is temporal (3D), use 'ModelSinoTemporal' function instead")
    return sinogram.transpose()
@cython.boundscheck(False)
@cython.wraparound(False)
def ModelSinoTemporal(int model_id, int image_size, int detector_size, np.ndarray[np.float32_t, ndim=1, mode="c"] angles, str model_parameters_filename):
    
    """
    function to build a 3D (2D +t) sinogram of the model: ModelSino (model_id, image_size, detector_size, angles, model_parameters_filename)
    
    Takes in as input model_id, image_size, detector_size and projection angles and return a 2D sinogram corresponding to the model id.
    
    param: model_parameters_filename -- filename for the model parameters
    param: model_id -- a model id from the functions file
    param: image_size -- a phantom size in each dimension.
    param: detector_size -- int detector size.
    param: angles -- a numpy array of float values with angles in radians
    param: CenTypeIn -- 1 as default [0: radon, 1:astra]
    returns: numpy float32 phantom sinograms array.    
    """    
    cdef float ret_val
    py_byte_string = model_parameters_filename.encode('UTF-8')
    cdef char* c_string = py_byte_string    
    cdef int AngTot = angles.shape[0]
    cdef int CenTypeIn = 1 # astra center positioning
    cdef np.ndarray[int, ndim=1, mode="c"] params
    params = np.ascontiguousarray(np.zeros([10], dtype=ctypes.c_int))
    checkParams2D(&params[0], model_id, c_string)
    testParams2D(params) # check parameters and terminate before running the core
    cdef np.ndarray[np.float32_t, ndim=3, mode="c"] sinogram = np.zeros([params[3], detector_size, angles.shape[0]], dtype='float32')
    if params[3] == 1:
        print("The selected model is stationary (2D), use 'ModelSino' function instead")
    else:
        ret_val = TomoP2DModelSino_core(&sinogram[0,0,0], model_id, image_size, detector_size, &angles[0], AngTot, CenTypeIn, c_string)
    return sinogram
@cython.boundscheck(False)
@cython.wraparound(False)
def ObjectSino(int image_size, int detector_size, np.ndarray[np.float32_t, ndim=1, mode="c"] angles, object_2d[:] obj_params):
    """
    ObjectSino (image_size, detector_size, angles,object parameters)
    
    Takes in as input object parameters list, image_size, detector_size and projection angles and return a 2D sinogram corresponding to the object
    
    param: image_size -- a phantom size in each dimension.
    param: detector_size -- int detector size.
    param: angles -- a numpy array of float values with angles in radians
    param: CenTypeIn -- 1 as default [0: radon, 1:astra]
    param: obj_params -- object parameters list
    returns: numpy float32 phantom sinograms array.
    
    """
    cdef Py_ssize_t i    
    cdef np.ndarray[np.float32_t, ndim=2, mode="c"] sinogram = np.zeros([detector_size,angles.shape[0]], dtype='float32')
    cdef float ret_val 
    cdef int AngTot = angles.shape[0]
    cdef int CenTypeIn = 1 # astra center posit
    for i in range(obj_params.shape[0]):
        ret_val = TomoP2DObjectSino_core(&sinogram[0,0], image_size, detector_size, &angles[0], AngTot, CenTypeIn, obj_params[i].Obj, obj_params[i].C0,-obj_params[i].y0, obj_params[i].x0, obj_params[i].a, obj_params[i].b, -obj_params[i].phi_rot, 0)
    return sinogram.transpose()

@cython.boundscheck(False)
@cython.wraparound(False)
def Object2(int phantom_size, objlist):
    cdef Py_ssize_t i
    cdef np.ndarray[np.float32_t, ndim=2, mode="c"] phantom = np.zeros([phantom_size, phantom_size], dtype='float32')
    cdef float ret_val
    
    if type(objlist) is dict:
        objlist = [objlist]
        
    
    for obj in objlist:
        if testParams(obj):
            
            stuff = bytes(obj['Obj'].value, 'ascii')
            
            ret_val = TomoP2DObject_core(&phantom[0,0], phantom_size, 
                                        stuff, 
                                        obj['C0'], 
                                        obj['x0'], 
                                        obj['y0'], 
                                        obj['a'], 
                                        obj['b'], 
                                        obj['phi'], 0)
            print ('ret_val', ret_val)
    return phantom


def testParams(obj):
    if not type(obj) is dict:
        raise TypeError('obj is not a dict {0}'.format(type(obj)))
    
    # type check    
    #typecheck = type(obj['Obj']) is str
    #if not typecheck:
    #    raise TypeError('Obj is not a string')
    #else:
    #    if not obj['Obj'] in ['gaussian', 'parabola', 'parabola1', 'ellipse', 'cone', 'rectangle']:
    #        raise ValueError('Model unknown: {0}'.format(obj['Obj']))
    
    typecheck = type(obj['x0']) is float
    if not typecheck:
        raise TypeError('C0 is not a float')
    typecheck = typecheck and type(obj['x0']) is float
    if not typecheck:
        raise TypeError('x0 is not a float')
    typecheck = typecheck and type(obj['y0']) is float
    if not typecheck:
        raise TypeError('y0 is not a float')
    typecheck = typecheck and type(obj['a']) is float
    if not typecheck:
        raise TypeError('a is not a float')
    typecheck = typecheck and type(obj['b']) is float
    if not typecheck:
        raise TypeError('b is not a float')
    typecheck = typecheck and type(obj['phi']) is float
    if not typecheck:
        raise TypeError('phi is not a float')
    
    # range check    
    rangecheck = obj['x0'] >= -1 and obj['x0'] <= 1
    if not rangecheck:
        raise ValueError('x0 is out of range. Must be between -1 and 1')
    rangecheck = rangecheck and obj['y0'] >= -1 and obj['y0'] <= 1
    if not rangecheck:
        raise ValueError('y0 is out of range. Must be between -1 and 1')
    rangecheck = rangecheck and obj['a'] > 0
    if not rangecheck:
        raise ValueError('a is not positive.')
    rangecheck = rangecheck and obj['b'] > 0
    if not rangecheck:
        raise ValueError('b is not positive.')
    return rangecheck and typecheck


def testParams2D(obj):
    if obj[0] == 0:
         raise TypeError('Check if the library file <Phantom2DLibrary.dat> exists, the given path is correct and the syntax is valid')
    if obj[1] == 0:
         raise TypeError('The given model is not found, check available models in <Phantom2DLibrary.dat> file')
    if obj[2] == 0:
         raise TypeError('Components number cannot be negative, check <Phantom2DLibrary.dat> file')
    if obj[3] == 0:
         raise TypeError('TimeSteps cannot be negative, check <Phantom2DLibrary.dat> file')
    if obj[4] == 0:
         raise TypeError('Unknown name of the object, check <Phantom2DLibrary.dat> file')
    if obj[5] == 0:
         raise TypeError('C0 should not be equal to zero, check <Phantom2DLibrary.dat> file')
    if obj[6] == 0:
         raise TypeError('x0 (object position) must be in [-1,1] range, check <Phantom2DLibrary.dat> file')
    if obj[7] == 0:
         raise TypeError('y0 (object position) must be in [-1,1] range, check <Phantom2DLibrary.dat> file')
    if obj[8] == 0:
         raise TypeError('a (object size) must be positive in [0,2] range, check <Phantom2DLibrary.dat> file')
    if obj[9] == 0:
         raise TypeError('b (object size) must be positive in [0,2] range, check <Phantom2DLibrary.dat> file')
    return 0