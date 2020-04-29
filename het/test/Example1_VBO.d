//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@debug

import het;

class MyWin: GLWindow{
  mixin autoCreate;  //automatically creates an instance of this form ath startup

  Shader shader;
  VBO vbo, vbo2;
  float phase = 0;  //animated position

  struct VRecord {
    V2f aPosition;  //*** the fieldnames must match the name of the shader attributes!
    uint aColor;
  };
  immutable VRecord[] vVertices = [ {{ 0.5,  0.5}, clRed   },
                                    {{-0.5,  0.5}, clLime  },
                                    {{ 0.5, -0.5}, clBlue  },
                                    {{-0.5, -0.5}, clYellow} ];

  override void onUpdate(){
    targetUpdateRate = 125;

    //animate                   //deltaTime is usually around 4ms by default.
    phase += deltaTime*(PI*2);  //you can set targetUpdateRate if you want to change it.
                                //it will not affect the VSynch-ed FrameRate.

    invalidate; //call this whenever a change happens that should be displayed.
  }

  void prepare(){ //prepare the shader and the VBO
    shader = new Shader("Test shader", q{
      uniform vec2 uShift;
      varying vec3 vColor;

      @vertex:
      attribute vec2 aPosition;
      attribute vec3 aColor;
      void main()
      {
        gl_Position = vec4(aPosition+uShift, 0, 1);
        vColor = aColor;
      }

      @fragment:
      void main()
      {
        gl_FragColor = vec4(vColor, 0);
      }
    });

    //create Vertex Buffer Object
    vbo = new VBO(vVertices);
    vbo2 = new VBO(vVertices);

  }

  override void onPaint(){ //the paint event
    if(!shader) prepare;

    gl.clearColor(RGB(0x201010));
    gl.clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    shader.uniform("uShift", V2f(cos(phase)*0.4f, sin(phase*0.92f)*0.4f));
    shader.attrib(vbo);

    vbo.draw(GL_TRIANGLE_STRIP);


    shader.uniform("uShift", V2f(cos(phase*1.1)*0.4f, sin(phase*0.82f)*0.4f));
    shader.attrib(vbo2);
    vbo2.draw(GL_TRIANGLE_STRIP);
  }
}


