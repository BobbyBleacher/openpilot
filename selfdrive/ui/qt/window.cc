#include "selfdrive/ui/qt/window.h"

#include <QFontDatabase>
#include <QFile>
#include <QTimer>
#include <QApplication>
#include <QMouseEvent>
#include <QTextStream>

#include "system/hardware/hw.h"

MainWindow::MainWindow(QWidget *parent) : QWidget(parent) {
  main_layout = new QStackedLayout(this);
  main_layout->setMargin(0);

  homeWindow = new HomeWindow(this);
  main_layout->addWidget(homeWindow);
  QObject::connect(homeWindow, &HomeWindow::openSettings, this, &MainWindow::openSettings);
  QObject::connect(homeWindow, &HomeWindow::closeSettings, this, &MainWindow::closeSettings);

  settingsWindow = new SettingsWindow(this);
  main_layout->addWidget(settingsWindow);
  QObject::connect(settingsWindow, &SettingsWindow::closeSettings, this, &MainWindow::closeSettings);
  QObject::connect(settingsWindow, &SettingsWindow::reviewTrainingGuide, [=]() {
    onboardingWindow->showTrainingGuide();
    main_layout->setCurrentWidget(onboardingWindow);
  });
  QObject::connect(settingsWindow, &SettingsWindow::showDriverView, [=] {
    homeWindow->showDriverView(true);
  });

  onboardingWindow = new OnboardingWindow(this);
  main_layout->addWidget(onboardingWindow);
  QObject::connect(onboardingWindow, &OnboardingWindow::onboardingDone, [=]() {
    main_layout->setCurrentWidget(homeWindow);
  });
  if (!onboardingWindow->completed()) {
    main_layout->setCurrentWidget(onboardingWindow);
  }

  QObject::connect(uiState(), &UIState::offroadTransition, [=](bool offroad) {
    if (!offroad) {
      closeSettings();
    }
  });
  QObject::connect(device(), &Device::interactiveTimeout, [=]() {
    if (main_layout->currentWidget() == settingsWindow) {
      closeSettings();
    }
  });

  // load fonts
  QFontDatabase::addApplicationFont("../assets/fonts/Inter-Black.ttf");
  QFontDatabase::addApplicationFont("../assets/fonts/Inter-Bold.ttf");
  QFontDatabase::addApplicationFont("../assets/fonts/Inter-ExtraBold.ttf");
  QFontDatabase::addApplicationFont("../assets/fonts/Inter-ExtraLight.ttf");
  QFontDatabase::addApplicationFont("../assets/fonts/Inter-Medium.ttf");
  QFontDatabase::addApplicationFont("../assets/fonts/Inter-Regular.ttf");
  QFontDatabase::addApplicationFont("../assets/fonts/Inter-SemiBold.ttf");
  QFontDatabase::addApplicationFont("../assets/fonts/Inter-Thin.ttf");
  QFontDatabase::addApplicationFont("../assets/fonts/JetBrainsMono-Medium.ttf");

  // no outline to prevent the focus rectangle
  setStyleSheet(R"(
    * {
      font-family: Inter;
      outline: none;
    }
  )");
  setAttribute(Qt::WA_NoSystemBackground);

  // Optional remote UI capture for development.
  // Enable with: touch /data/ui_capture_enabled
  QTimer *capture_timer = new QTimer(this);

  QObject::connect(capture_timer, &QTimer::timeout, [=]() {
    if (QFile::exists("/data/ui_capture_enabled")) {
      this->grab().save(
        "/data/ui_capture.jpg",
        "JPG",
        80
      );
    }
  });

  capture_timer->start(1000);

  QTimer *remote_input_timer = new QTimer(this);

  QObject::connect(remote_input_timer, &QTimer::timeout, this, [this]() {
    const QString click_file = "/data/ui_remote_click";

    if (!QFile::exists("/data/ui_capture_enabled") ||
        !QFile::exists(click_file)) {
      return;
    }

    QFile file(click_file);

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
      return;
    }

    QTextStream stream(&file);

    double nx = 0.0;
    double ny = 0.0;
    stream >> nx >> ny;

    file.close();
    QFile::remove(click_file);

    const int x = qBound(0, int(nx * width()), width() - 1);
    const int y = qBound(0, int(ny * height()), height() - 1);

    QPoint window_pos(x, y);
    QPoint global_pos = mapToGlobal(window_pos);

    QWidget *target = QApplication::widgetAt(global_pos);

    if (target == nullptr) {
      return;
    }

    QPoint local_pos = target->mapFromGlobal(global_pos);

    QMouseEvent press(
      QEvent::MouseButtonPress,
      local_pos,
      Qt::LeftButton,
      Qt::LeftButton,
      Qt::NoModifier
    );

    QApplication::sendEvent(target, &press);

    QMouseEvent release(
      QEvent::MouseButtonRelease,
      local_pos,
      Qt::LeftButton,
      Qt::NoButton,
      Qt::NoModifier
    );

    QApplication::sendEvent(target, &release);
  });

  remote_input_timer->start(100);
}

void MainWindow::openSettings(int index, const QString &param) {
  main_layout->setCurrentWidget(settingsWindow);
  settingsWindow->setCurrentPanel(index, param);
}

void MainWindow::closeSettings() {
  main_layout->setCurrentWidget(homeWindow);

  if (uiState()->scene.started) {
    homeWindow->showSidebar(false);
    // Map is always shown when using navigate on openpilot
    if (uiState()->scene.navigate_on_openpilot) {
      homeWindow->showMapPanel(true);
    }
  }
}

bool MainWindow::eventFilter(QObject *obj, QEvent *event) {
  bool ignore = false;
  switch (event->type()) {
    case QEvent::TouchBegin:
    case QEvent::TouchUpdate:
    case QEvent::TouchEnd:
    case QEvent::MouseButtonPress:
    case QEvent::MouseMove: {
      // ignore events when device is awakened by resetInteractiveTimeout
      ignore = !device()->isAwake();
      device()->resetInteractiveTimeout();
      break;
    }
    default:
      break;
  }
  return ignore;
}
