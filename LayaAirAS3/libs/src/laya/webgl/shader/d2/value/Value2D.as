package laya.webgl.shader.d2.value {
	import laya.resource.Bitmap;
	import laya.webgl.WebGLContext;
	import laya.webgl.canvas.DrawStyle;
	import laya.webgl.shader.Shader;
	import laya.webgl.shader.ShaderValue;
	import laya.webgl.shader.d2.Shader2D;
	import laya.webgl.shader.d2.Shader2X;
	import laya.webgl.shader.d2.ShaderDefines2D;
	import laya.webgl.utils.CONST3D2D;
	import laya.webgl.utils.RenderState2D;

	/**
	 * ...
	 * @author laya
	 */
	public class Value2D  extends ShaderValue
	{
		public static var _POSITION:Array;
		public static var _TEXCOORD:Array;
		public static  var needRezise:Boolean;
		
		protected static var _cache:Array=[];
		protected static var _typeClass:Object = [];

		private static function _initone(type:int, classT:*):void
		{
			_typeClass[type] = classT;
			_cache[type] = [];
			_cache[type]._length = 0;
		}
		
		public static function __init__():void
		{
			_POSITION = [2, WebGLContext.FLOAT, false, 4 * CONST3D2D.BYTES_PE, 0];
			_TEXCOORD = [2, WebGLContext.FLOAT, false, 4 * CONST3D2D.BYTES_PE, 2 * CONST3D2D.BYTES_PE];
			_initone(ShaderDefines2D.COLOR2D, Color2dSV);
			_initone(ShaderDefines2D.PRIMITIVE, PrimitiveSV);
			_initone(ShaderDefines2D.TEXTURE2D, TextureSV);
			_initone(ShaderDefines2D.TEXTURE2D | ShaderDefines2D.COLORADD,TextSV);	
			_initone(ShaderDefines2D.TEXTURE2D | ShaderDefines2D.FILTERGLOW, TextureSV);
		}
		
		public var defines:ShaderDefines2D = new ShaderDefines2D();
		public var position:Array = _POSITION;
		public var size:Array=[0,0];
		public var alpha:Number = 1.0;
		public var mmat:Array;
		public var ALPHA:Number = 1.0;
		
		public var shader:Shader;
		public var mainID:int;
		public var subID:int=0;
		public var filters:Array;
		
		public var textureHost:*;
		public var texture:*;
		public var fillStyle:DrawStyle;
		public var color:Array;
		public var strokeStyle:DrawStyle;
		public var colorAdd:Array;
		public var glTexture:Bitmap;
		public var u_mmat2:Array;
		
		private var _inClassCache:Array;
		//private var _initDef:int;
		private var _cacheID:int = 0;
		
		public function Value2D(mainID:int,subID:int)
		{
			this.mainID = mainID;
			this.subID = subID;
			
			this.textureHost = null;
			this.texture = null;
			this.fillStyle = null;
			this.color = null;
			this.strokeStyle = null;
			this.colorAdd = null;
			this.glTexture = null;
			this.u_mmat2 = null;
			
			_cacheID = mainID|subID;
			_inClassCache = _cache[_cacheID];
			if (mainID>0 && !_inClassCache)
			{
				_inClassCache = _cache[_cacheID] = [];
				_inClassCache._length = 0;
			}
			//_initDef=(_cacheID == (ShaderDefines2D.TEXTURE2D | ShaderDefines2D.COLORADD))?ShaderDefines2D.COLORADD:mainID;
			clear();
			
		}		
		
		public function setValue(value:Shader2D):void{}
			//throw new Error("todo in subclass");
		
		public function refresh():ShaderValue
		{
			var size:Array = this.size;
			size[0] = RenderState2D.width;
			size[1] = RenderState2D.height;
			alpha = ALPHA * RenderState2D.worldAlpha;
			mmat = RenderState2D.worldMatrix4;
			return this;
		}
		
		private function _ShaderWithCompile():Shader2X
		{
			try{
				return Shader.withCompile(0, mainID, defines.toString(), mainID | defines._value | RenderState2D.worldShaderDefinesValue, Shader2X.create) as Shader2X;
			}
			catch (e:*)
			{
			}
			return null;
		}
		
		private function _withWorldShaderDefinesValue():void
		{
			try{
				var sd:Shader2X = Shader.sharders[mainID | defines._value | RenderState2D.worldShaderDefinesValue] as Shader2X || _ShaderWithCompile();
				var worldFilters:Array = RenderState2D.worldFilters;
				var n:int = worldFilters.length,f:*;
				for (var i:int = 0; i < n; i++)
				{
					( (f= worldFilters[i])) && f.action.setValue(this);
				}
			}
			catch (e:*)
			{
			}
		}
		
		public function upload():void
		{
			var sd:Shader2X;
			var renderstate2d:*= RenderState2D;
			alpha = ALPHA * renderstate2d.worldAlpha;
			
			renderstate2d.worldShaderDefinesValue?_withWorldShaderDefinesValue()
				:(sd = Shader.sharders[mainID | defines._value] as Shader2X || _ShaderWithCompile());
			
			var params:Array;
		
			if (Shader.activeShader!==sd)
			{
				mmat = renderstate2d.worldMatrix4;
				if (renderstate2d.width !== sd._shaderValueWidth || renderstate2d.height !== sd._shaderValueHeight)
				{
					this.size[0] = sd._shaderValueWidth = renderstate2d.width;
					this.size[1] = sd._shaderValueHeight = renderstate2d.height;
				}
				else params = sd._params2dQuick2 || sd._make2dQuick2();
        	    sd.upload(this, params);
			}
			else
			{
				var  needResize:Boolean = Value2D.needRezise;
				if (needResize)
				{
				   this.size[0] = sd._shaderValueWidth = renderstate2d.width;
				   this.size[1] = sd._shaderValueHeight = renderstate2d.height;
				   var preParams:Array = sd._params2dQuick1;
				   sd._params2dQuick1 = null;
				   params = sd._make2dQuick1();
				   sd.upload(this, params);
				   sd._params2dQuick1 = preParams;
				}
				else
				{
				   params = (sd._params2dQuick1) || sd._make2dQuick1();
				   sd.upload(this, params);
				}
			}
		}
		
		public function setFilters(value:Array):void
		{
			if (!value) return;
			filters = value;
			var n:int = value.length,f:*;
			for (var i:int = 0; i < n; i++)
			{
				f= value[i]
				if (f)
				{
					defines.add(f.type);//搬到setValue中
					f.action.setValue(this);
				}
			}
		}
		
		public function clear():void
		{
			defines.setValue(subID);
		}
		
		public function release():void
		{
			_inClassCache[_inClassCache._length++] = this;
			this.clear();
		}
		
		public static function create(mainType:int,subType:int):Value2D
		{
			var types:Array = _cache[mainType|subType];
			if (types._length)
				return types[--types._length];
			else
				return new _typeClass[mainType|subType](subType);
		}
		public static  function  reset():void
		{
			 (Value2D.needRezise) && (Value2D.needRezise=false);
		}
		/*
		public static function createShderValue(type:int,filters:Array):Value2D
		{
			var value:Value2D=Value2D.create(type,0);
			var len:int=filters.length;
			for(var i:int=0;i<len;i++)
			{
				filters[i].action.setValue(value);
				value.defines.add(filters[i].type);
			}
			return value;
		}
		
		public static function createShderValueMix(type:int,filters:Array):Value2D
		{
			var value:Value2D=Value2D.create(type,0);
			var len:int=filters.length;
			for(var i:int=0;i<len;i++)
			{
				filters[i].action.setValueMix(value);
				value.defines.add(filters[i].action.typeMix);
			}
			return  value;
		}*/
		
	}

}