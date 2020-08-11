//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@debug

import het, het.ui;

enum Unit{ pcs, g, kg, l }

struct ProductPrice{
  float quantity=0;
  Unit unit;
  float price=0;

  auto nominal() const{
    struct Res{
      float price;
      Unit unit;
    }
    final switch(unit){
      case(Unit.kg ): return Res(price*1   /quantity, Unit.kg );
      case(Unit.g  ): return Res(price*1000/quantity, Unit.kg );
      case(Unit.l  ): return Res(price*1   /quantity, Unit.l  );
      case(Unit.pcs): return Res(price*1   /quantity, Unit.pcs);
    }
  }
}

class Product{
  string name;
  ProductPrice[2] prices;
}


class FrmDemo: GLWindow { mixin autoCreate; // FrmDemo ////////////////////////////

  Product[] products;

  auto dataFile(){ return File(appPath, "products.json"); }

  override void onCreate(){
    products.fromJson(dataFile.readText(false));
  }

  override void onDestroy(){
    dataFile.write(products.toJson);
  }

  override void onUpdate(){
    invalidate; //todo: opt
    view.navigate(!im.wantKeys, !im.wantMouse);

    with(im) Panel(PanelPosition.topLeft, { //client position
      width = clientWidth;
      margin = "0"; padding = "0";
      vScroll;

      Row({
        if(Btn("Add product")){
          products ~= new Product;
        }
      });

      Spacer;

      foreach(productIdx, product; products) with(product){
        Row({
          Edit(name, { width = 12*fh; });
          Spacer;
        });
      }



    });

  }

  override void onPaint(){
    dr.clear;
    drGUI.clear; //todo: why is this mandatory
    im.draw(drGUI);
  }
}


