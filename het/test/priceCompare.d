//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@debug

import het, het.ui;

enum Unit{ db, g, kg, l }

struct Price{
  DateTime when;
  string where;
  float quantity=0;
  float price=0;
  bool isPurchased;
}

class Product{
  string name;
  Unit unit;
  Price[] prices;
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

      sizediff_t removeProductIdx = -1,
                 insertProductIdx = -1;
      foreach(productIdx, product; products) with(product){
        Row({
          if(Btn(symbol("Add"))) insertProductIdx = productIdx;
          Edit(name, { width = 20*fh; });
          ComboBox(unit, { width = 3*fh; });
          if(Btn({ style.fontColor = clRed; Symbol("Remove"); })) removeProductIdx = productIdx;

          Spacer;


        });
      }
      Row({
        if(Btn(symbol("Add"))) insertProductIdx = products.length;
        Spacer; Text("Add new product");
      });

      if(removeProductIdx >= 0) products = products.remove(removeProductIdx);
      if(insertProductIdx >= 0) products.insertInPlace(insertProductIdx, new Product);


    });

  }

  override void onPaint(){
    dr.clear(clSilver);
    drGUI.clear; //todo: why is this mandatory
    im.draw(drGUI);
  }
}


