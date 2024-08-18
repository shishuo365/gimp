/* LIBGIMP - The GIMP Library
 * Copyright (C) 1995-1997 Peter Mattis and Spencer Kimball
 *
 * This library is free software: you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library.  If not, see
 * <https://www.gnu.org/licenses/>.
 */

#include "config.h"

#include <babl/babl.h>
#include <glib-object.h>

#include "libgimpmath/gimpmath.h"

#include "gimpcolortypes.h"

#include "gimpcolorspace.h"
#include "gimprgb.h"
#include "gimphsv.h"



/**
 * SECTION: gimpcolorspace
 * @title: GimpColorSpace
 * @short_description: Utility functions which convert colors between
 *                     different color models.
 *
 * When programming pixel data manipulation functions you will often
 * use algorithms operating on a color model different from the one
 * GIMP uses.  This file provides utility functions to convert colors
 * between different color spaces.
 **/


/*  GimpRGB functions  */


/**
 * gimp_rgb_to_hsv:
 * @rgb: A color value in the RGB colorspace
 * @hsv: (out caller-allocates): The value converted to the HSV colorspace
 *
 * Does a conversion from RGB to HSV (Hue, Saturation,
 * Value) colorspace.
 **/
void
gimp_rgb_to_hsv (const GimpRGB *rgb,
                 GimpHSV       *hsv)
{
  gdouble max, min, delta;

  g_return_if_fail (rgb != NULL);
  g_return_if_fail (hsv != NULL);

  max = gimp_rgb_max (rgb);
  min = gimp_rgb_min (rgb);

  hsv->v = max;
  delta = max - min;

  if (delta > 0.0001)
    {
      hsv->s = delta / max;

      if (rgb->r == max)
        {
          hsv->h = (rgb->g - rgb->b) / delta;
          if (hsv->h < 0.0)
            hsv->h += 6.0;
        }
      else if (rgb->g == max)
        {
          hsv->h = 2.0 + (rgb->b - rgb->r) / delta;
        }
      else
        {
          hsv->h = 4.0 + (rgb->r - rgb->g) / delta;
        }

      hsv->h /= 6.0;
    }
  else
    {
      hsv->s = 0.0;
      hsv->h = 0.0;
    }

  hsv->a = rgb->a;
}

/**
 * gimp_hsv_to_rgb:
 * @hsv: A color value in the HSV colorspace
 * @rgb: (out caller-allocates): The returned RGB value.
 *
 * Converts a color value from HSV to RGB colorspace
 **/
void
gimp_hsv_to_rgb (const GimpHSV *hsv,
                 GimpRGB       *rgb)
{
  gint    i;
  gdouble f, w, q, t;

  gdouble hue;

  g_return_if_fail (rgb != NULL);
  g_return_if_fail (hsv != NULL);

  if (hsv->s == 0.0)
    {
      rgb->r = hsv->v;
      rgb->g = hsv->v;
      rgb->b = hsv->v;
    }
  else
    {
      hue = hsv->h;

      if (hue == 1.0)
        hue = 0.0;

      hue *= 6.0;

      i = (gint) hue;
      f = hue - i;
      w = hsv->v * (1.0 - hsv->s);
      q = hsv->v * (1.0 - (hsv->s * f));
      t = hsv->v * (1.0 - (hsv->s * (1.0 - f)));

      switch (i)
        {
        case 0:
          rgb->r = hsv->v;
          rgb->g = t;
          rgb->b = w;
          break;
        case 1:
          rgb->r = q;
          rgb->g = hsv->v;
          rgb->b = w;
          break;
        case 2:
          rgb->r = w;
          rgb->g = hsv->v;
          rgb->b = t;
          break;
        case 3:
          rgb->r = w;
          rgb->g = q;
          rgb->b = hsv->v;
          break;
        case 4:
          rgb->r = t;
          rgb->g = w;
          rgb->b = hsv->v;
          break;
        case 5:
          rgb->r = hsv->v;
          rgb->g = w;
          rgb->b = q;
          break;
        }
    }

  rgb->a = hsv->a;
}
