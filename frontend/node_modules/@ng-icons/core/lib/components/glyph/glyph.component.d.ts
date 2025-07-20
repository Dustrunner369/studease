import * as i0 from "@angular/core";
export declare class NgGlyph {
    /**
     * Access the available glyphsets
     */
    private readonly glyphsets;
    /**
     * Access the default configuration
     */
    private readonly config;
    /**
     * Define the name of the glyph to display
     */
    readonly name: import("@angular/core").InputSignal<string>;
    /**
     * Define the glyphset to use
     */
    readonly glyphset: import("@angular/core").InputSignal<string>;
    /**
     * Define the optical size of the glyph
     */
    readonly opticalSize: import("@angular/core").InputSignalWithTransform<number, unknown>;
    /**
     * Define the weight of the glyph
     */
    readonly weight: import("@angular/core").InputSignalWithTransform<number, unknown>;
    /**
     * Define the grade of the glyph
     */
    readonly grade: import("@angular/core").InputSignalWithTransform<number, unknown>;
    /**
     * Define the fill of the glyph
     */
    readonly fill: import("@angular/core").InputSignalWithTransform<boolean, unknown>;
    /**
     * Define the size of the glyph
     */
    readonly size: import("@angular/core").InputSignalWithTransform<string | number, string>;
    /**
     * Define the color of the glyph
     */
    readonly color: import("@angular/core").InputSignal<string>;
    /**
     * Derive the glyphset class from the glyphset name
     */
    protected readonly glyphsetClass: import("@angular/core").Signal<string>;
    /**
     * Define the font variation settings of the glyph
     */
    protected readonly fontVariationSettings: import("@angular/core").Signal<string>;
    static ɵfac: i0.ɵɵFactoryDeclaration<NgGlyph, never>;
    static ɵcmp: i0.ɵɵComponentDeclaration<NgGlyph, "ng-glyph", never, { "name": { "alias": "name"; "required": true; "isSignal": true; }; "glyphset": { "alias": "glyphset"; "required": false; "isSignal": true; }; "opticalSize": { "alias": "opticalSize"; "required": false; "isSignal": true; }; "weight": { "alias": "weight"; "required": false; "isSignal": true; }; "grade": { "alias": "grade"; "required": false; "isSignal": true; }; "fill": { "alias": "fill"; "required": false; "isSignal": true; }; "size": { "alias": "size"; "required": false; "isSignal": true; }; "color": { "alias": "color"; "required": false; "isSignal": true; }; }, {}, never, never, true, never>;
}
