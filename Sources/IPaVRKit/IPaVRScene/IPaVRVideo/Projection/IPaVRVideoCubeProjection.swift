//
//  IPaVRVideoCubeProjection.swift
//  IPaVRKit
//
//  Created by IPa Chen on 2021/12/21.
//

import SceneKit

class IPaVRVideoCubeProjection: IPaVRVideoGeometryProjection {
    let halfSide:Float = 400
    override func createGeometry() -> SCNGeometry {
    //reference https://stackoverflow.com/questions/38949083/scenekit-map-cube-texture-to-box

        /* The cube vertex are like:

            5---------4
           /.        /|
          / .       / |
         7---------6  |
         |  .      |  |
         |  .      |  |
         |  1......|..0
         | .       | /
         |.        |/
         3---------2

         */
        let _positions = [
            SCNVector3(x:halfSide, y:-halfSide, z:  -halfSide),
            SCNVector3(x:-halfSide, y:-halfSide, z:  -halfSide),
            SCNVector3(x:halfSide, y:-halfSide, z: halfSide),
            SCNVector3(x:-halfSide, y:-halfSide, z: halfSide),
            SCNVector3(x:halfSide, y: halfSide, z:  -halfSide),
            SCNVector3(x:-halfSide, y: halfSide, z:  -halfSide),
            SCNVector3(x:halfSide, y: halfSide, z: halfSide),
            SCNVector3(x:-halfSide, y: halfSide, z: halfSide),
        ]

        // points are tripled since they are each used on 3 faces
        // and there's no continuity in the UV mapping
        // so we need to duplicate the points
        //
       
        let positions = _positions + _positions
        
        let X:Int16 = 0
        let Y:Int16 = 8

        //face to center
    
        let indices:[Int16] = [
            // left
            1 + X, 5 + X, 3 + X,
            3 + X, 5 + X, 7 + X,

            // front
            0 + X, 4 + X, 1 + X,
            1 + X, 4 + X, 5 + X,

            // right
            0 + X, 2 + X, 4 + X,
            4 + X, 2 + X, 6 + X,

            // bottom
            0 + Y, 1 + Y, 3 + Y,
            3 + Y, 2 + Y, 0 + Y,

            // back
            2 + Y, 3 + Y, 6 + Y,
            6 + Y, 3 + Y, 7 + Y,

            // top
            4 + Y, 6 + Y, 5 + Y,
            5 + Y, 6 + Y, 7 + Y,
        ]

        // get the points in the texture where the faces are split
        var textureSplitPoints = [CGPoint]()
        for i in 0..<12 {
            let x = Double(i % 4)
            let y = Double(i / 4)
            textureSplitPoints.append(CGPoint(x: x / 3.0, y: 1 - (y / 2.0)))
        }
        
        /* texture uv index
         0 ----- 1 ------ 2 ----- 3
         |       |        |       |
         4 ----- 5 ------ 6 ----- 7
         |       |        |       |
         8 ----- 9 ------ 10 ---- 11
         
         */
    
    
        let textCoords = [
            textureSplitPoints[6],
            textureSplitPoints[5],
            textureSplitPoints[7],
            textureSplitPoints[4],
            textureSplitPoints[2],
            textureSplitPoints[1],
            textureSplitPoints[3],
            textureSplitPoints[0],

            textureSplitPoints[4],
            textureSplitPoints[8],
            textureSplitPoints[5],
            textureSplitPoints[9],
            textureSplitPoints[7],
            textureSplitPoints[11],
            textureSplitPoints[6],
            textureSplitPoints[10],

        ]
        
        
        let vertexSource = SCNGeometrySource(vertices: positions)
        //normal is not used, but default shader need normal data
        //if no normal data, there will be a shader error
        let normalSource = SCNGeometrySource(normals: positions)
        let textSource = SCNGeometrySource(textureCoordinates: textCoords)
        let intSize = MemoryLayout<Int16>.size
        let indexData = Data(bytes: indices, count: intSize * indices.count)
        
        let elements = SCNGeometryElement(
            data: indexData,
            primitiveType: SCNGeometryPrimitiveType.triangles,
            primitiveCount: indices.count / 3,
            bytesPerIndex: intSize
        )
        return SCNGeometry(sources: [vertexSource,normalSource, textSource], elements: [elements])
    }
}
