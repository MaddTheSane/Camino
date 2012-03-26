# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

ifndef LIBXUL_SDK
include $(topsrcdir)/toolkit/toolkit-tiers.mk
endif

TIERS += app

ifdef MOZ_EXTENSIONS
tier_app_dirs += extensions
endif

ifdef MOZ_BRANDING_DIRECTORY
tier_app_dirs += $(MOZ_BRANDING_DIRECTORY)
endif

tier_app_dirs += \
	camino \
	$(NULL)

package:
	@$(MAKE) -C camino/installer
