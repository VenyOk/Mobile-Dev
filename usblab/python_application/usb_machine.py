import os
import platform
import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional
import serial, time
from serial.tools import list_ports

import typer
from rich.console import Console
import sys

import usb
from usb.core import Device, Endpoint

# import usb.core
# import usb.backend.libusb1
# backend = usb.backend.libusb1.get_backend(find_library=lambda x: "/usr/lib/usb")

if platform.system() == "Darwin" and "arm" in platform.platform():
    os.environ["DYLD_LIBRARY_PATH"] = "/opt/homebrew/lib"


class AppMode(Enum):
    Write = "write"
    Read = "read"
    # WriteArduino = 'write-arduino'


@dataclass
class App:
    device: Optional[Device] = None
    console: Optional[Console] = field(default_factory=Console)

    def detect_xiaomi_device(self):
        """Определяет, является ли устройство Xiaomi"""
        try:
            if not self.device:
                return False
            device_name = usb.util.get_string(self.device, self.device.iProduct)
            if device_name and ("xiaomi" in device_name.lower() or "mi " in device_name.lower() or "redmi" in device_name.lower()):
                return True
        except:
            pass
        return False

    def diagnose_usb_issues(self):
        """Диагностика проблем с USB на Windows"""
        if platform.system() != "Windows":
            return
        
        self.console.print("[bold yellow]Диагностика USB проблем на Windows...")
        
        # Проверка backend
        try:
            import usb.backend.libusb1
            backend = usb.backend.libusb1.get_backend()
            if backend:
                self.console.print("[green]✓ libusb backend доступен")
            else:
                self.console.print("[red]✗ libusb backend недоступен")
        except Exception as e:
            self.console.print(f"[red]✗ Ошибка при загрузке libusb backend: {e}")
            self.console.print(
                "[yellow]Решение: Установите libusb:\n"
                "  1. Скачайте с https://github.com/libusb/libusb/releases\n"
                "  2. Скопируйте libusb-1.0.dll в C:\\Windows\\System32\\\n"
                "  3. Или используйте Zadig для установки драйверов"
            )
        
        # Попытка найти устройства с разными методами
        self.console.print("\n[bold]Попытка найти USB устройства...")
        try:
            devices = list(usb.core.find(find_all=True))
            if devices:
                self.console.print(f"[green]✓ Найдено {len(devices)} USB устройств")
                for i, dev in enumerate(devices[:3]):  # Показываем первые 3
                    try:
                        name = usb.util.get_string(dev, dev.iProduct)
                        self.console.print(f"  [{i}] {name}")
                    except:
                        self.console.print(f"  [{i}] Устройство (ID: {hex(dev.idVendor)}:{hex(dev.idProduct)})")
            else:
                self.console.print("[red]✗ USB устройства не найдены")
        except Exception as e:
            self.console.print(f"[red]✗ Ошибка при поиске устройств: {e}")
            self.console.print(
                "[yellow]Возможные причины:\n"
                "  1. Драйверы не установлены (используйте Zadig)\n"
                "  2. Устройство не подключено\n"
                "  3. Нужны права администратора\n"
                "  4. libusb не установлен"
            )

    def select_device(self):
        # Попытка найти устройства с обработкой ошибок
        try:
            lst: list[usb.Device] = list(usb.core.find(find_all=True))
        except Exception as e:
            self.console.print(f"[bold red]Ошибка при поиске USB устройств: {e}")
            if platform.system() == "Windows":
                self.console.print(
                    "[bold yellow]На Windows требуется установка драйверов libusb.\n"
                    "Попробуйте:\n"
                    "1. Установить Zadig (https://zadig.akeo.ie/) и установить драйвер WinUSB для вашего устройства\n"
                    "2. Или установить libusb библиотеку и скопировать libusb-1.0.dll в System32\n"
                    "3. Запустить скрипт от имени администратора"
                )
            sys.exit(1)
        
        if not lst:
            self.console.print(r"[bold blue]Waiting for devices...")
            self.console.print("[dim]Подключите Android устройство через USB и включите отладку по USB")
            
            # Запускаем диагностику на Windows
            if platform.system() == "Windows":
                self.diagnose_usb_issues()
                self.console.print("\n[bold blue]Продолжаем ожидание устройств...")
            
            attempt = 0
            while not lst:
                try:
                    lst = list(usb.core.find(find_all=True))
                    attempt += 1
                    if attempt % 5 == 0:  # Каждые 5 секунд выводим подсказку
                        self.console.print(
                            "[dim]Все еще ждем... Убедитесь, что:\n"
                            "  - Устройство подключено через USB\n"
                            "  - На телефоне включена отладка по USB\n"
                            "  - Драйверы установлены правильно"
                        )
                except Exception as e:
                    self.console.print(f"[bold red]Ошибка при поиске устройств: {e}")
                    if platform.system() == "Windows":
                        self.console.print("[bold yellow]На Windows могут потребоваться драйверы libusb!")
                time.sleep(1)

        if len(lst) == 1:
            dev = lst[0]
            device_name = ""
            try:
                device_name = usb.util.get_string(dev, dev.iProduct)
            except:
                device_name = "Unknown device"
            
            self.console.print(
                rf"[bold blue]Single device is available, using [bold green]{device_name}"
            )
            
            # Проверяем, является ли устройство Xiaomi
            self.device = dev
            if self.detect_xiaomi_device():
                self.console.print(
                    "[bold yellow]⚠ Обнаружено устройство Xiaomi/MIUI\n"
                    "[dim]На устройствах Xiaomi могут потребоваться дополнительные настройки:\n"
                    "  1. Включите режим разработчика (7 раз нажмите на номер сборки)\n"
                    "  2. Включите 'Отладка по USB'\n"
                    "  3. Включите 'USB-отладка (безопасность)' если доступно\n"
                    "  4. Отключите 'Оптимизация батареи' для приложения\n"
                    "  5. В настройках USB выберите 'Передача файлов (MTP)'\n"
                    "  6. Разрешите доступ к USB Accessory при запросе на телефоне"
                )
        else:
            self.console.print("[bold blue]Available devices:")
            for i, dev in enumerate(lst):
                try:
                    self.console.print(
                        f"  [bold green][{i}] {usb.util.get_string(dev, dev.iProduct)}"
                    )
                except ValueError as e:
                    pass
            ind = self.console.input("[bold blue]Select device index: ")
            dev = lst[int(ind)]

        self.device = dev

    def prepare_device(self):
        for command_name, command in [
            ("Verifying protocol", self.set_protocol),
            ("Sending accessory parameters", self.send_accessory_parameters),
            ("Triggering accessory mode", self.set_accessory_mode),
        ]:
            self.console.print(f"{command_name}......... ", end="")
            try:
                command()
            except:
                self.console.print("[bold red]FAIL")
                self.console.print_exception()
                sys.exit(1)
            else:
                self.console.print("[bold green]OK")

    def set_protocol(self):
        try:
            self.device.set_configuration()
        except usb.core.USBError as e:
            if e.errno != 16:  # 16 == already configured
                raise

        ret = self.device.ctrl_transfer(0xC0, 51, 0, 0, 2)
        protocol = ret[0]
        if protocol < 2:
            raise ValueError(f"Protocol version {protocol} < 2 is not supported")
        return

    def send_accessory_parameters(self):
        def send_string(str_id, str_val):
            ret = self.device.ctrl_transfer(0x40, 52, 0, str_id, str_val, 0)
            if ret != len(str_val):
                raise ValueError("Received non-valid response")
            return

        send_string(0, "dvpashkevich")
        send_string(1, "PyAndroidCompanion")
        send_string(2, "A Python based Android accessory companion")
        send_string(3, "0.1.0")
        send_string(4, "https://github.com/alien-agent/USB-Communicator-Script")
        send_string(5, "0000-0000-0000")
        return

    def check_if_already_in_accessory_mode(self):
        """Проверяет, находится ли устройство уже в Accessory Mode"""
        try:
            # Пытаемся получить протокол - если устройство уже в Accessory Mode,
            # это может не сработать или вернуть другую информацию
            # Альтернативно, проверяем по VID/PID или другим признакам
            devices = list(usb.core.find(find_all=True))
            if devices:
                # Если устройство уже в Accessory Mode, оно может иметь специфические VID/PID
                # или мы можем попробовать подключиться напрямую
                for dev in devices:
                    try:
                        # Пытаемся получить конфигурацию - если устройство в Accessory Mode,
                        # это должно работать
                        cfg = dev.get_active_configuration()
                        # Если получили конфигурацию, возможно устройство уже в Accessory Mode
                        return True
                    except:
                        continue
            return False
        except:
            return False

    def set_accessory_mode(self):
        # Проверяем, не находится ли устройство уже в Accessory Mode
        # (например, если Flutter приложение уже подключено)
        self.console.print("[dim]Проверка текущего режима устройства...")
        
        # Пытаемся найти устройство, которое уже может быть в Accessory Mode
        try:
            devices_after = list(usb.core.find(find_all=True))
            if devices_after:
                # Пробуем использовать существующее устройство
                # Если Flutter уже подключен, устройство может быть занято
                self.console.print("[yellow]Обнаружено устройство. Проверяем, не занято ли оно...")
                
                # Пробуем переключить в Accessory Mode
                # Если устройство уже в Accessory Mode, команда может не сработать
                try:
                    ret = self.device.ctrl_transfer(0x40, 53, 0, 0, "", 0)
                    if ret:
                        raise ValueError("Failed to trigger accessory mode")
                except usb.core.USBError as e:
                    # Если ошибка "Resource busy" или подобная, устройство может быть занято
                    if e.errno == 16 or "busy" in str(e).lower() or "resource" in str(e).lower():
                        self.console.print(
                            "[bold yellow]Устройство занято другим приложением (возможно, Flutter приложением).\n"
                            "[dim]Попробуйте:\n"
                            "  1. Закрыть Flutter приложение на телефоне\n"
                            "  2. Или запустить Python скрипт ПЕРЕД запуском Flutter приложения\n"
                            "  3. Или отключить и снова подключить телефон"
                        )
                        # Пытаемся найти устройство в Accessory Mode
                        time.sleep(1)
                        devices = list(usb.core.find(find_all=True))
                        if devices:
                            self.device = devices[0]
                            self.console.print("[green]Используем существующее подключение")
                            return
                        else:
                            raise ValueError("Device is busy and cannot be accessed")
                    else:
                        raise
        except Exception as e:
            # Если проверка не удалась, продолжаем обычный процесс
            pass
        
        # Обычный процесс переключения в Accessory Mode
        ret = self.device.ctrl_transfer(0x40, 53, 0, 0, "", 0)
        if ret:
            raise ValueError("Failed to trigger accessory mode")
        
        # После переключения в Accessory Mode устройство переподключается
        # На Android 15 может потребоваться больше времени
        self.console.print("\n[dim]Ожидание переподключения устройства...")
        self.console.print("[dim]На Android 15 это может занять больше времени...")
        time.sleep(3)  # Увеличиваем время ожидания для Android 15

        # Пытаемся найти устройство несколько раз
        # На Android 15 может потребоваться больше попыток
        dev = None
        max_attempts = 15  # Увеличиваем количество попыток для Android 15
        for attempt in range(max_attempts):
            try:
                # Ищем устройство по VID/PID или просто первое доступное
                devices = list(usb.core.find(find_all=True))
                if devices:
                    # После переключения в Accessory Mode устройство может иметь другие параметры
                    # Берем первое доступное устройство
                    dev = devices[0]
                    break
                time.sleep(0.5)  # Ждем 0.5 секунды между попытками
            except Exception as e:
                self.console.print(f"[dim]Попытка {attempt + 1}/{max_attempts}...")
                time.sleep(0.5)
        
        if not dev:
            # Проверяем, является ли устройство Xiaomi для специальных инструкций
            is_xiaomi = self.detect_xiaomi_device() if hasattr(self, 'device') and self.device else False
            
            xiaomi_help = ""
            if is_xiaomi:
                xiaomi_help = (
                    "[bold cyan]Специально для Xiaomi/MIUI:\n"
                    "  • Проверьте настройки безопасности MIUI\n"
                    "  • Отключите 'Блокировку USB-отладки' в настройках разработчика\n"
                    "  • Включите 'USB-отладка (безопасность)'\n"
                    "  • Разрешите 'Установку через USB' если запрашивается\n"
                    "  • Проверьте, не блокирует ли MIUI Optimizer USB-соединения\n"
                )
            
            android15_help = (
                "[bold cyan]Для Android 15 (API 35):\n"
                "  • Android 15 имеет более строгие требования безопасности\n"
                "  • Убедитесь, что приложение имеет все необходимые разрешения\n"
                "  • Проверьте настройки USB в параметрах разработчика\n"
                "  • Может потребоваться больше времени для переключения в Accessory Mode\n"
            )
            
            self.console.print(
                "[bold yellow]Устройство не найдено после переключения в Accessory Mode.\n"
                "[dim]Возможные причины:\n"
                "  1. Flutter приложение уже использует устройство - закройте его\n"
                "  2. Устройство не переключилось в Accessory Mode\n"
                "  3. Драйверы не установлены правильно\n"
                "  4. Настройки безопасности на телефоне блокируют доступ\n"
                "  5. Проблемы совместимости с Android 15\n"
                f"{android15_help}"
                f"{xiaomi_help}"
                "[bold]Попробуйте:\n"
                "  1. Закрыть Flutter приложение на телефоне\n"
                "  2. Отключить и снова подключить телефон\n"
                "  3. Запустить Python скрипт ПЕРЕД запуском Flutter приложения\n"
                "  4. Убедитесь, что на телефоне разрешен доступ к USB Accessory\n"
                "  5. Проверьте настройки разработчика на телефоне\n"
                "  6. Для Android 15: перезагрузите телефон и попробуйте снова"
            )
            raise ValueError(
                "Device gone missing after accessory mode trigger, please restart"
            )
        
        self.device = dev
        self.console.print("[green]Устройство найдено после переключения в Accessory Mode")
        return

    def accept_data(self):
        self.console.print("[bold blue]Accepting data...")
        
        consecutive_errors = 0
        max_consecutive_errors = 5
        
        while True:
            try:
                # Получаем конфигурацию и интерфейс каждый раз (на случай переподключения)
                cfg = self.device.get_active_configuration()
                if_num = cfg[(0, 0)].bInterfaceNumber
                intf = usb.util.find_descriptor(cfg, bInterfaceNumber=if_num)

                ep_in: Endpoint = usb.util.find_descriptor(
                    intf,
                    custom_match=lambda e: usb.util.endpoint_direction(e.bEndpointAddress)
                    == usb.util.ENDPOINT_IN,
                )
                
                # Используем таймаут вместо 0, чтобы не блокировать навсегда
                data = ep_in.read(size_or_buffer=1024, timeout=1000)  # 1 секунда таймаут
                if data:
                    print(bytes(data).decode())
                    consecutive_errors = 0  # Сброс счетчика ошибок при успешном чтении
                    
            except usb.core.USBError as e:
                consecutive_errors += 1
                error_code = e.errno if hasattr(e, 'errno') else None
                
                # Разные типы ошибок USB
                if error_code == 110:  # TIMEOUT - это нормально, просто продолжаем
                    consecutive_errors = 0
                    continue
                elif error_code == 19:  # No such device - устройство отключилось
                    self.console.print(f"[bold red]Устройство отключено (ошибка {error_code})")
                    self.console.print("[yellow]Попытка переподключения...")
                    
                    # Пытаемся найти устройство снова
                    time.sleep(1)
                    devices = list(usb.core.find(find_all=True))
                    if devices:
                        self.device = devices[0]
                        self.console.print("[green]Устройство переподключено")
                        consecutive_errors = 0
                        continue
                    else:
                        self.console.print("[bold red]Устройство не найдено. Подключите телефон снова.")
                        break
                else:
                    if consecutive_errors < max_consecutive_errors:
                        self.console.print(f"[dim]Ошибка USB (код {error_code}): {e}. Попытка {consecutive_errors}/{max_consecutive_errors}...")
                        time.sleep(0.5)
                        continue
                    else:
                        self.console.print(f"[bold red]Слишком много ошибок подряд. Остановка.")
                        break
                        
            except KeyboardInterrupt:
                self.console.print("\n[bold yellow]Прерывание пользователем...")
                try:
                    self.device.detach_kernel_driver(0)
                except:
                    pass
                break
            except Exception as e:
                consecutive_errors += 1
                self.console.print(f"[bold red]Неожиданная ошибка: {e}")
                if consecutive_errors >= max_consecutive_errors:
                    break
                time.sleep(1)

    def write(self):
        while True:
            try:
                # Получаем конфигурацию и интерфейс каждый раз (на случай переподключения)
                cfg = self.device.get_active_configuration()
                if_num = cfg[(0, 0)].bInterfaceNumber
                intf = usb.util.find_descriptor(cfg, bInterfaceNumber=if_num)

                ep_out: Endpoint = usb.util.find_descriptor(
                    intf,
                    custom_match=lambda e: usb.util.endpoint_direction(e.bEndpointAddress)
                    == usb.util.ENDPOINT_OUT,
                )
                
                message = self.console.input("[bold blue]Write: ")
                if not message:
                    continue
                    
                ep_out.write(message.encode() if isinstance(message, str) else message)
                self.console.print("[green]Сообщение отправлено")
                
            except usb.core.USBError as e:
                error_code = e.errno if hasattr(e, 'errno') else None
                if error_code == 19:  # No such device
                    self.console.print("[bold red]Устройство отключено. Попытка переподключения...")
                    time.sleep(1)
                    devices = list(usb.core.find(find_all=True))
                    if devices:
                        self.device = devices[0]
                        self.console.print("[green]Устройство переподключено")
                        continue
                    else:
                        self.console.print("[bold red]Устройство не найдено. Подключите телефон снова.")
                        break
                else:
                    self.console.print(f"[bold red]Ошибка при отправке: {e}")
                    
            except KeyboardInterrupt:
                self.console.print("\n[bold yellow]Прерывание пользователем...")
                break
            except Exception as e:
                self.console.print(f"[bold red]Неожиданная ошибка: {e}")
                time.sleep(1)

    def write_arduino(self):
        ports = list(serial.tools.list_ports.comports())
        target_port = None
        for p in ports:
            if "usb" in str(p.usb_info()).lower():
                target_port = p
        if target_port is None:
            self.console.print("[bold red]No USB ports found!")
            sys.exit(1)
        self.console.print(f"[bold blue]Writing to {target_port.device}")

        while True:
            user_input = input()
            if user_input in ["0", "1"]:
                with serial.Serial(target_port.device, 9600) as ser:
                    ser.write(user_input.encode())


def main(mode: AppMode = AppMode.Read.value):
    app = App()
    
    # Проверка прав администратора на Windows
    if platform.system() == "Windows":
        try:
            import ctypes
            is_admin = ctypes.windll.shell32.IsUserAnAdmin() != 0
            if not is_admin:
                app.console.print(
                    "[bold yellow]ВНИМАНИЕ: Скрипт запущен без прав администратора.\n"
                    "На Windows может потребоваться запуск от имени администратора для работы с USB."
                )
        except:
            pass
    
    # if mode == AppMode.WriteArduino:
    #     app.write_arduino()
    # else:
    app.select_device()
    app.prepare_device()

    if mode == AppMode.Write:
        app.write()
    else:
        app.accept_data()


if __name__ == "__main__":
    typer.run(main)