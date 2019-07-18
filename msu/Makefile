#
#  Copyright 2019 Supranational, LLC
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

SDACCEL_DIR=rtl/sdaccel

all:
	$(MAKE) -C rtl regression

judge:
	$(MAKE) clean

	@echo "Running functional tests..."
	$(MAKE) -C rtl judge

	@echo "Running hardware emulation..."
	$(MAKE) hw_emu_random

	@echo "Synthesizing..."
	$(MAKE) hw

hw_emu:
	$(MAKE) -C $(SDACCEL_DIR) hw_emu

hw_emu_random:
	$(MAKE) -C $(SDACCEL_DIR) hw_emu_random

hw:
	$(MAKE) -C $(SDACCEL_DIR) hw

clean:
	$(MAKE) -C rtl clean
	$(MAKE) -C $(SDACCEL_DIR) clean

